require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::SecureFDPasser do
  it "sends and receives FDs over a UNIX socket" do
    server = UNIXServer.new("/tmp/test_dbus_fd.sock")
    begin
      client = UNIXSocket.new("/tmp/test_dbus_fd.sock")
      server_client = server.accept

      # Create some dummy file descriptors (e.g. by opening a file)
      file = File.open("/dev/null")
      fds = [file.fd]
      data = "dummy".to_slice

      Crystal::Dbus::Native::SecureFDPasser.send_fds(client, data, fds)

      buffer = Bytes.new(5)
      result, received_fds, cred = Crystal::Dbus::Native::SecureFDPasser.recv_fds(server_client, buffer)

      result.should be > 0
      buffer.should eq("dummy".to_slice)
      received_fds.size.should eq(1)
      received_fds[0].should be > 0

      file.close
    ensure
      File.delete("/tmp/test_dbus_fd.sock") if File.exists?("/tmp/test_dbus_fd.sock")
    end
  end

  it "raises ArgumentError when sending too many FDs" do
    client = UNIXSocket.new(Socket::Family::UNIX, Socket::Type::STREAM)
    fds = Array.new(254, 0)
    expect_raises(Crystal::Dbus::Native::DBusError, "Too many FDs") do
      Crystal::Dbus::Native::SecureFDPasser.send_fds(client, "dummy".to_slice, fds)
    end
    client.close
  end

  it "raises ArgumentError when max_fds is too large during recv" do
    client = UNIXSocket.new(Socket::Family::UNIX, Socket::Type::STREAM)
    expect_raises(Crystal::Dbus::Native::DBusError, "max_fds too large") do
      Crystal::Dbus::Native::SecureFDPasser.recv_fds(client, Bytes.new(5), 254)
    end
    client.close
  end
end
