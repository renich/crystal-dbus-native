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

    @serial_mutex : Sync::Mutex
    @next_serial : UInt32

    # Initializes a new `DBusConnection` wrapping an open `UNIXSocket`.
    def initialize(@socket : UNIXSocket) : Nil
      @serial_mutex = Sync::Mutex.new
      @next_serial = 1_u32
      @unique_name = nil
      @server_guid = nil
    end

    # Opens a connection to the user's session D-Bus socket.
    def self.open_session : self
      address = ENV["DBUS_SESSION_BUS_ADDRESS"]? || "/run/user/#{LibC.getuid}/bus"
      path = parse_unix_path(address)
      new(UNIXSocket.new(path))
    end

    # Opens a connection to the system D-Bus socket.
    def self.open_system : self
      address = ENV["DBUS_SYSTEM_BUS_ADDRESS"]? || "/var/run/dbus/system_bus_socket"
      path = parse_unix_path(address)
      new(UNIXSocket.new(path))
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
      end

      if hello
        hello_msg = DBusMessage.method_call(
          serial: next_serial,
          path: "/org/freedesktop/DBus",
          interface: "org.freedesktop.DBus",
          member: "Hello",
          destination: "org.freedesktop.DBus"
        )
        send(hello_msg)
        @unique_name = extract_unique_name(receive)
      end

      @unique_name || @server_guid || ""
    end

    # Serializes and flushes a `DBusMessage` to the underlying socket.
    def send(msg : DBusMessage) : Nil
      msg.serialize(@socket)
      @socket.flush
    end

    # Reads and parses the next `DBusMessage` from the underlying socket.
    def receive : DBusMessage
      DBusMessage.parse(@socket)
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

    # Closes the underlying socket connection if open.
    def close : Nil
      @socket.close unless @socket.closed?
    end

    # Returns `true` if the underlying socket is closed.
    def closed? : Bool
      @socket.closed?
    end

    private def extract_unique_name(reply : DBusMessage) : String
      case reply.message_type
      when MessageType::MethodReturn
        reply.read_string_body
      when MessageType::Error
        raise DBusError.new("Hello failed: #{reply.error_name}")
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
