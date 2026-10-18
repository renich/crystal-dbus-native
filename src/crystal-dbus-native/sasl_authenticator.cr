require "socket"

module Crystal::Dbus::Native
  # Implements the client-side D-Bus SASL `EXTERNAL` authentication and feature negotiation protocol.
  class SASLAuthenticator
    # Maximum allowed length in bytes for a single SASL handshake response line.
    MAX_LINE_LENGTH = 4096

    # Authenticates `client` using the SASL `EXTERNAL` mechanism for `uid` and returns the server GUID.
    def self.authenticate(
      client : UNIXSocket, uid : UInt32, timeout : Time::Span = 1.second, negotiate_unix_fd : Bool = false,
    ) : String
      old_timeout = client.read_timeout
      client.read_timeout = timeout
      begin
        client.write_byte(0_u8)
        client << "AUTH EXTERNAL #{uid.to_s.to_slice.hexstring}\r\n"
        client.flush
        response = read_response(client)
        unless response.starts_with?("OK ") || response == "OK"
          raise AuthError.new("Authentication failed: #{response}")
        end
        guid = response.size > 3 ? response[3..-1].strip : ""
        negotiate_unix_fd(client, negotiate_unix_fd)
        client << "BEGIN\r\n"
        client.flush
        guid
      ensure
        client.read_timeout = old_timeout
      end
    end

    private def self.negotiate_unix_fd(socket : UNIXSocket, negotiate_fd : Bool) : Bool
      return false unless negotiate_fd
      socket << "NEGOTIATE_UNIX_FD\r\n"
      socket.flush
      fd_resp = read_response(socket)
      unless fd_resp.starts_with?("AGREE_UNIX_FD")
        raise AuthError.new("Unix FD passing negotiation rejected: #{fd_resp}")
      end
      true
    end

    private def self.read_response(client : UNIXSocket) : String
      line = client.gets(limit: MAX_LINE_LENGTH, chomp: true)
      raise ConnectionClosedError.new("Connection closed during SASL handshake") if line.nil?
      if line.bytesize >= MAX_LINE_LENGTH - 1
        raise AuthError.new("SASL response line exceeds maximum length")
      end
      line
    rescue IO::TimeoutError
      raise AuthError.new("SASL handshake timed out")
    end
  end
end
