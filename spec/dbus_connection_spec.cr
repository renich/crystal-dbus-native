require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::DBusConnection do
  it "starts and gracefully closes" do
    server = UNIXServer.new("/tmp/test_dbus_conn.sock")
    begin
      client = UNIXSocket.new("/tmp/test_dbus_conn.sock")
      server_conn = server.accept

      conn = Crystal::Dbus::Native::DBusConnection.new(client)
      conn.start

      # Should gracefully close without hanging
      conn.close

      client.closed?.should be_true
      server_conn.close
    ensure
      File.delete("/tmp/test_dbus_conn.sock") if File.exists?("/tmp/test_dbus_conn.sock")
    end
  end
end
