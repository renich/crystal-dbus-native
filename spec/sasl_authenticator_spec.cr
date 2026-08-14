require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::SASLAuthenticator do
  describe ".authenticate" do
    it "authenticates successfully" do
      server = UNIXServer.new("/tmp/test_dbus_sasl.sock")
      begin
        # Use spawn to run the server side of SASL
        spawn do
          conn = server.accept

          # Read NUL byte
          conn.read_byte

          # Read AUTH EXTERNAL <uid_hex>
          req = conn.gets("\r\n")
          if req && req.starts_with?("AUTH EXTERNAL")
            conn << "OK 1234567890abcdef\r\n"
            conn.flush

            # Read BEGIN
            conn.gets("\r\n")
          end
          conn.close
        end

        client = UNIXSocket.new("/tmp/test_dbus_sasl.sock")
        uid = 1000_u32
        guid = Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, uid)
        guid.should eq("1234567890abcdef")
        client.close
      ensure
        File.delete("/tmp/test_dbus_sasl.sock") if File.exists?("/tmp/test_dbus_sasl.sock")
      end
    end

    it "raises exception on failed authentication" do
      server = UNIXServer.new("/tmp/test_dbus_sasl_fail.sock")
      begin
        spawn do
          conn = server.accept
          conn.read_byte
          conn.gets("\r\n")
          conn << "REJECTED\r\n"
          conn.flush
          conn.close
        end

        client = UNIXSocket.new("/tmp/test_dbus_sasl_fail.sock")
        uid = 1000_u32
        expect_raises(Crystal::Dbus::Native::AuthError, "Authentication failed") do
          Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, uid)
        end
        client.close
      ensure
        File.delete("/tmp/test_dbus_sasl_fail.sock") if File.exists?("/tmp/test_dbus_sasl_fail.sock")
      end
    end

    it "raises exception on read timeout" do
      server = UNIXServer.new("/tmp/test_dbus_sasl_timeout.sock")
      begin
        spawn do
          conn = server.accept
          # Read but do not respond
          conn.read_byte
          conn.gets("\r\n")
          # Just wait and close after long
          sleep 0.2.seconds
          conn.close unless conn.closed?
        end

        client = UNIXSocket.new("/tmp/test_dbus_sasl_timeout.sock")
        uid = 1000_u32

        # Override AUTH_TIMEOUT for tests if possible, but testing with a small timeout or real timeout
        expect_raises(Crystal::Dbus::Native::AuthError, "Read timeout") do
          # Simulate short timeout to not wait 5s
          # We'll just patch the timeout for this test or accept the wait.
          # For a quick test we could use a mock socket, but a timeout is thrown.
          # Here we just wait 5s or we need to stub the timeout if possible.
          Crystal::Dbus::Native::SASLAuthenticator.authenticate(client, uid)
        end
        client.close
      ensure
        File.delete("/tmp/test_dbus_sasl_timeout.sock") if File.exists?("/tmp/test_dbus_sasl_timeout.sock")
      end
    end
  end
end
