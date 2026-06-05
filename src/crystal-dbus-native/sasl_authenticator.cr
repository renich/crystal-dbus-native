require "socket"

module Crystal::Dbus::Native
  class SASLAuthenticator
    def self.authenticate(client : UNIXSocket, uid : UInt32) : String
      client.read_timeout = 100.milliseconds

      client.write_byte(0_u8)
      hex_uid = uid.to_s.bytes.map(&.to_s(16)).join
      client << "AUTH EXTERNAL #{hex_uid}\r\n"
      client.flush

      begin
        response = client.gets("\r\n", chomp: true)
      rescue IO::TimeoutError
        raise AuthError.new("Read timeout")
      end

      if response.nil?
        raise ConnectionClosedError.new("Connection closed")
      end

      if response.starts_with?("OK ")
        guid = response.byte_slice(3)
        client << "BEGIN\r\n"
        client.flush
        guid
      else
        raise AuthError.new("Authentication failed: #{response}")
      end
    end
  end
end
