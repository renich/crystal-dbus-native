require "socket"
require "sync/mutex"

module Crystal::Dbus::Native
  # Manages a native UNIX domain socket connection to a D-Bus message bus daemon.
  class DBusConnection
    # Returns the unique bus connection name assigned during the `Hello` handshake.
    getter unique_name : String?
    # Returns the server GUID obtained during SASL authentication.
    getter server_guid : String?
    # Returns the underlying `UNIXSocket` transport.
    getter socket : UNIXSocket
    # Returns `true` if `NEGOTIATE_UNIX_FD` succeeded during the SASL handshake.
    getter? unix_fd_negotiated : Bool

    @serial_mutex = Sync::Mutex.new
    @io_mutex = Sync::Mutex.new
    @next_serial = 1_u32
    @router = ReplyRouter.new
    @reader_running = false

    # Initializes a new `DBusConnection` wrapping an open `UNIXSocket`.
    def initialize(@socket : UNIXSocket) : Nil
      @socket.sync = true
      @socket.read_buffering = false
      @unique_name = nil
      @server_guid = nil
      @unix_fd_negotiated = false
    end

    # Opens a connection to the user's session D-Bus socket.
    def self.open_session : self
      address = ENV["DBUS_SESSION_BUS_ADDRESS"]? || "/run/user/#{LibC.getuid}/bus"
      new(UNIXSocket.new(parse_unix_path(address)))
    end

    # Opens a connection to the system D-Bus socket.
    def self.open_system : self
      address = ENV["DBUS_SYSTEM_BUS_ADDRESS"]? || "/var/run/dbus/system_bus_socket"
      new(UNIXSocket.new(parse_unix_path(address)))
    end

    # Performs the SASL authentication and `org.freedesktop.DBus.Hello` bus registration handshake.
    def start(
      uid : UInt32 = LibC.getuid,
      authenticate : Bool = true,
      hello : Bool = true,
      negotiate_unix_fd : Bool = false,
    ) : String
      if authenticate
        @server_guid = SASLAuthenticator.authenticate(@socket, uid, negotiate_unix_fd: negotiate_unix_fd)
        @unix_fd_negotiated = negotiate_unix_fd
      end
      if hello
        send(DBusMessage.method_call(next_serial, "/org/freedesktop/DBus",
          "org.freedesktop.DBus", "Hello", "org.freedesktop.DBus"))
        @unique_name = extract_unique_name(receive)
      end
      @unique_name || @server_guid || ""
    end

    # Serializes and sends `msg` over the socket, optionally passing `fds` via `SCM_RIGHTS`.
    def send(msg : DBusMessage, fds : Array(Int32) = Array(Int32).new) : Nil
      @io_mutex.synchronize do
        if fds.empty?
          msg.serialize(@socket)
          @socket.flush
        else
          raise DBusError.new("UNIX FD passing was not negotiated on this connection") unless @unix_fd_negotiated
          msg.unix_fds = fds.size.to_u32
          SecureFDPasser.send_fds(@socket, msg.to_slice, fds)
        end
      end
    end

    # Reads and parses the next `DBusMessage` from the underlying socket.
    def receive : DBusMessage
      DBusMessage.parse(@socket)
    end

    # Reads and parses the next `DBusMessage` along with any ancillary file descriptors passed via `SCM_RIGHTS`.
    def receive_with_fds(max_size : UInt32 = 134_217_728_u32) : Tuple(DBusMessage, Array(Int32))
      header_buf = uninitialized StaticArray(UInt8, 16)
      header = header_buf.to_slice
      bytes_read, fds = SecureFDPasser.recv_fds(@socket, header)
      if bytes_read == 0
        fds.each { |descriptor| LibC.close(descriptor) }
        raise ConnectionClosedError.new("Connection closed reading fixed message header")
      end
      begin
        @socket.read_fully(header[bytes_read..]) if bytes_read < 16
        {DBusMessage.parse_from_header(header, @socket, max_size), fds}
      rescue ex
        fds.each { |descriptor| LibC.close(descriptor) }
        raise ex
      end
    end

    # Invokes a D-Bus method and awaits its matching reply via the multiplexed fiber reply router.
    def call(
      destination : String, path : String, interface : String, member : String,
      signature : String? = nil, values : Array(Value) = Array(Value).new,
    ) : DBusMessage
      serial = next_serial
      msg = DBusMessage.method_call(serial, path, interface, member, destination)
      msg.encode_body(signature, values) if signature
      ch = @router.register_reply(serial)
      begin
        send(msg)
        start_reader
        await_reply(ch)
      ensure
        @router.unregister_reply(serial)
      end
    end

    # Subscribes to D-Bus signals matching `match_rule`, returning a bounded `Channel(DBusMessage)`.
    def subscribe_signal(match_rule : String, send_bus_match : Bool = true) : Channel(DBusMessage)
      channel = @router.subscribe(match_rule)
      begin
        if send_bus_match
          call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
            "AddMatch", "s", [match_rule.as(Value)])
        else
          start_reader
        end
        channel
      rescue ex
        @router.unsubscribe(match_rule, channel)
        raise ex
      end
    end

    # Unsubscribes `channel` from `match_rule` and optionally calls `org.freedesktop.DBus.RemoveMatch`.
    def unsubscribe_signal(
      match_rule : String, channel : Channel(DBusMessage), send_bus_match : Bool = true,
    ) : Nil
      @router.unsubscribe(match_rule, channel)
      return unless send_bus_match
      call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
        "RemoveMatch", "s", [match_rule.as(Value)])
    end

    # Starts the background reader fiber if not already running.
    def start_reader : Nil
      should_spawn = @serial_mutex.synchronize do
        !@reader_running && (@reader_running = true)
      end
      spawn { run_reader_loop } if should_spawn
    end

    # Returns the number of currently registered pending reply channels.
    def pending_reply_count : Int32
      @router.pending_reply_count
    end

    # Pops and returns the next buffered signal message, or `nil` if the signal queue is empty.
    def poll_signal : DBusMessage?
      @router.poll_signal
    end

    # Allocates the next non-zero monotonically increasing 32-bit message serial in a thread-safe manner.
    def next_serial : UInt32
      @serial_mutex.synchronize do
        serial = @next_serial
        @next_serial &+= 1
        @next_serial = 1_u32 if @next_serial == 0_u32
        serial
      end
    end

    # Closes the underlying socket connection and all pending reply/signal channels.
    def close : Nil
      @socket.close unless @socket.closed?
      @router.close_all
    end

    # Returns `true` if the underlying socket is closed.
    def closed? : Bool
      @socket.closed?
    end

    private def run_reader_loop : Nil
      loop do
        break if @socket.closed?
        @router.dispatch(receive)
      end
    rescue IO::Error | DBusError
    ensure
      @router.close_all
    end

    private def await_reply(ch : Channel(DBusMessage)) : DBusMessage
      reply = ch.receive? || raise ConnectionClosedError.new("Connection closed waiting for reply")
      if reply.message_type == MessageType::Error
        raise DBusError.new("D-Bus call failed: #{reply.error_name || "unknown error"}")
      end
      reply
    end

    private def extract_unique_name(reply : DBusMessage) : String
      case reply.message_type
      when MessageType::MethodReturn then reply.read_string_body
      when MessageType::Error        then raise DBusError.new("Hello failed: #{reply.error_name}")
      else
        raise DBusError.new("Unexpected message type in Hello reply: #{reply.message_type}")
      end
    end

    private def self.parse_unix_path(address : String) : String
      return address unless address.starts_with?("unix:path=")
      address.byte_slice(10).partition(',')[0]
    end
  end
end
