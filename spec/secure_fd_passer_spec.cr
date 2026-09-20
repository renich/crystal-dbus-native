require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::SecureFDPasser do
  it "sends and receives FDs over a UNIX socket pair" do
    client, peer = UNIXSocket.pair(Socket::Type::STREAM)
    file = File.open("/dev/null")
    begin
      fds = [file.fd]
      data = "dummy".to_slice

      Crystal::Dbus::Native::SecureFDPasser.send_fds(client, data, fds)

      buffer = Bytes.new(5)
      result, received_fds = Crystal::Dbus::Native::SecureFDPasser.recv_fds(peer, buffer)

      result.should be > 0
      buffer.should eq("dummy".to_slice)
      received_fds.size.should eq(1)
      received_fds[0].should be > 0

      # Close received file descriptor to prevent descriptor leak
      received_fds.each { |descriptor| LibC.close(descriptor) }
    ensure
      file.close
      client.close
      peer.close
    end
  end

  it "raises when sending too many FDs" do
    client, peer = UNIXSocket.pair(Socket::Type::STREAM)
    fds = Array.new(254, 0)
    begin
      expect_raises(Crystal::Dbus::Native::DBusError, /Too many FDs/) do
        Crystal::Dbus::Native::SecureFDPasser.send_fds(client, "dummy".to_slice, fds)
      end
    ensure
      client.close
      peer.close
    end
  end

  it "raises when max_fds is too large during recv" do
    client, peer = UNIXSocket.pair(Socket::Type::STREAM)
    begin
      expect_raises(Crystal::Dbus::Native::DBusError, /max_fds too large/) do
        Crystal::Dbus::Native::SecureFDPasser.recv_fds(client, Bytes.new(5), 254)
      end
    ensure
      client.close
      peer.close
    end
  end
end
