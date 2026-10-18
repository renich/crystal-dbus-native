require "./spec_helper"
require "socket"

# Verifies [FUNC-001] / [TECH-001], [TECH-005]
describe Crystal::Dbus::Native::SASLAuthenticator do
  describe ".authenticate" do
    it "authenticates successfully with UID" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.read_byte
        req = server.gets("\r\n")
        if req && req.starts_with?("AUTH EXTERNAL")
          server << "OK 1234567890abcdef\r\n"
          server.flush
          server.gets("\r\n")
        end
        server.close
      end

      uid = 1000_u32
      guid = Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, uid)
      guid.should eq("1234567890abcdef")
      client.close
    end

    it "negotiates unix fd passing when requested" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.read_byte
        req = server.gets("\r\n")
        if req && req.starts_with?("AUTH EXTERNAL")
          server << "OK 1234567890abcdef\r\n"
          server.flush

          fd_req = server.gets("\r\n")
          if fd_req == "NEGOTIATE_UNIX_FD\r\n" || fd_req == "NEGOTIATE_UNIX_FD"
            server << "AGREE_UNIX_FD\r\n"
            server.flush
          end

          server.gets("\r\n")
        end
        server.close
      end

      guid = Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, 1000_u32, negotiate_unix_fd: true)
      guid.should eq("1234567890abcdef")
      client.close
    end

    it "raises exception on failed authentication" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.read_byte
        server.gets("\r\n")
        server << "REJECTED\r\n"
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::AuthError, "Authentication failed") do
        Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, 1000_u32)
      end
      client.close
    end

    it "raises exception on read timeout" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      done = Channel(Nil).new(1)
      spawn do
        server.read_byte
        server.gets("\r\n")
        done.receive
        server.close unless server.closed?
      end

      begin
        expect_raises(Crystal::Dbus::Native::AuthError, "SASL handshake timed out") do
          Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, 1000_u32, timeout: 0.01.seconds)
        end
      ensure
        done.send(nil)
        client.close
      end
    end

    it "raises exception when SASL response line exceeds maximum length" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.read_byte
        server.gets("\r\n")
        server << "OK " << ("a" * 4100) << "\r\n"
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::AuthError, "SASL response line exceeds maximum length") do
        Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, 1000_u32)
      end
      client.close
    end

    it "raises exception when connection closes unexpectedly" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.read_byte
        server.close
      end

      expect_raises(Crystal::Dbus::Native::ConnectionClosedError, "Connection closed") do
        Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, 1000_u32)
      end
      client.close
    end
  end
end
