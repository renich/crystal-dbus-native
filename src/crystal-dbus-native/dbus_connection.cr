require "socket"
require "sync/mutex"

module Crystal::Dbus::Native
  class DBusConnection
    getter unique_name : String?
    getter socket : UNIXSocket

    @serial_mutex : Sync::Mutex
    @next_serial : UInt32

    def initialize(@socket : UNIXSocket)
      @serial_mutex = Sync::Mutex.new
      @next_serial = 1_u32
      @unique_name = nil
    end

    def self.open_session : self
      address = ENV["DBUS_SESSION_BUS_ADDRESS"]? || "/run/user/#{LibC.getuid}/bus"
      path = parse_unix_path(address)
      new(UNIXSocket.new(path))
    end

    def self.open_system : self
      address = ENV["DBUS_SYSTEM_BUS_ADDRESS"]? || "/var/run/dbus/system_bus_socket"
      path = parse_unix_path(address)
      new(UNIXSocket.new(path))
    end

    def start(uid : UInt32 = LibC.getuid, authenticate : Bool = true, hello : Bool = true) : String
      if authenticate
        SASLAuthenticator.authenticate(@socket, uid)
      end

      if hello
        hello_serial = next_serial
        hello_msg = DBusMessage.method_call(
          serial: hello_serial,
          path: "/org/freedesktop/DBus",
          interface: "org.freedesktop.DBus",
          member: "Hello",
          destination: "org.freedesktop.DBus"
        )
        send(hello_msg)

        reply = receive
        if reply.message_type == MessageType::MethodReturn
          if reply.body.size >= 4
            name_len = IO::ByteFormat::LittleEndian.decode(UInt32, reply.body[0, 4])
            if reply.body.size >= 4 + name_len
              @unique_name = String.new(reply.body[4, name_len])
            end
          end
        elsif reply.message_type == MessageType::Error
          raise DBusError.new("Hello failed: #{reply.error_name}")
        end
      end

      @unique_name || ":1.0"
    end

    def send(msg : DBusMessage) : Nil
      msg.serialize(@socket)
      @socket.flush
    end

    def receive : DBusMessage
      DBusMessage.parse(@socket)
    end

    def next_serial : UInt32
      @serial_mutex.synchronize do
        serial = @next_serial
        @next_serial &+= 1
        serial
      end
    end

    def close : Nil
      @socket.close unless @socket.closed?
    end

    def closed? : Bool
      @socket.closed?
    end

    private def self.parse_unix_path(address : String) : String
      if address.starts_with?("unix:path=")
        address.byte_slice(10).split(',').first
      else
        address
      end
    end
  end
end
