require "socket"

module Crystal::Dbus::Native
  class SASLAuthenticator
    def self.authenticate(client : UNIXSocket, uid : UInt32, timeout : Time::Span = 1.second, negotiate_unix_fd : Bool = false) : String
      old_timeout = client.read_timeout
      client.read_timeout = timeout

      begin
        # D-Bus specification §3.4: Initial null byte
        client.write_byte(0_u8)

        hex_uid = uid.to_s.to_slice.hexstring
        client << "AUTH EXTERNAL #{hex_uid}\r\n"
        client.flush

        response = read_response(client)

        unless response.starts_with?("OK ") || response == "OK"
          raise AuthError.new("Authentication failed: #{response}")
        end

        guid = response.size > 3 ? response[3..-1].strip : ""

        if negotiate_unix_fd
          client << "NEGOTIATE_UNIX_FD\r\n"
          client.flush
          fd_resp = read_response(client)
          unless fd_resp.starts_with?("AGREE_UNIX_FD")
            raise AuthError.new("Unix FD passing negotiation rejected: #{fd_resp}")
          end
        end

        client << "BEGIN\r\n"
        client.flush
        guid
      ensure
        client.read_timeout = old_timeout
      end
    end

    private def self.read_response(client : UNIXSocket) : String
      line = client.gets("\r\n", chomp: true)
      raise ConnectionClosedError.new("Connection closed during SASL handshake") if line.nil?
      line
    rescue IO::TimeoutError
      raise AuthError.new("SASL handshake timed out")
    end
  end
end
