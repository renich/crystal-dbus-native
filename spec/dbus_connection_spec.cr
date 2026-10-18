require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::DBusConnection do
  it "starts and performs SASL and Hello handshake" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      server.read_byte
      server.gets("\r\n")
      server << "OK 1234567890abcdef\r\n"
      server.flush
      server.gets("\r\n")

      msg = Crystal::Dbus::Native::DBusMessage.parse(server)
      msg.member.should eq("Hello")

      reply = Crystal::Dbus::Native::DBusMessage.method_return(
        serial: 10_u32,
        reply_serial: msg.serial,
        destination: ":1.123"
      )
      reply.encode_body("s", [":1.123".as(Crystal::Dbus::Native::Value)])
      reply.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    conn.start(1000_u32).should eq(":1.123")
    conn.unique_name.should eq(":1.123")
    conn.server_guid.should eq("1234567890abcdef")
    conn.close
    conn.closed?.should be_true
  end

  it "raises DBusError when Hello reply is an Error" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      msg = Crystal::Dbus::Native::DBusMessage.parse(server)
      err_reply = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::Error,
        11_u32
      )
      err_reply.error_name = "org.freedesktop.DBus.Error.Failed"
      err_reply.reply_serial = msg.serial
      err_reply.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    expect_raises(Crystal::Dbus::Native::DBusError, "Hello failed") do
      conn.start(1000_u32, authenticate: false, hello: true)
    end
    conn.close
  end

  it "raises MessageError when Hello reply body is truncated" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      msg = Crystal::Dbus::Native::DBusMessage.parse(server)
      reply = Crystal::Dbus::Native::DBusMessage.method_return(
        serial: 12_u32,
        reply_serial: msg.serial,
        body: Bytes[10, 0, 0, 0, 'a'.ord.to_u8]
      )
      reply.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    expect_raises(Crystal::Dbus::Native::MessageError, "String body length exceeds payload bounds") do
      conn.start(1000_u32, authenticate: false, hello: true)
    end
    conn.close
  end

  it "increments serials monotonically in a thread-safe manner" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    serials = Array(UInt32).new
    mutex = Sync::Mutex.new
    done = Channel(Nil).new

    10.times do
      spawn do
        serial_num = conn.next_serial
        mutex.synchronize { serials << serial_num }
        done.send(nil)
      end
    end

    10.times { done.receive }
    serials.uniq.size.should eq(10)
    conn.close
    server.close
  end

  it "calls a method, buffers interleaved signals, and returns matching reply" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      req = Crystal::Dbus::Native::DBusMessage.parse(server)
      req.member.should eq("GetId")
      req.decode_body.should eq(["arg1".as(Crystal::Dbus::Native::Value)])

      sig_msg = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::Signal,
        50_u32
      )
      sig_msg.path = "/org/freedesktop/DBus"
      sig_msg.interface = "org.freedesktop.DBus"
      sig_msg.member = "NameAcquired"
      sig_msg.encode_body("s", [":1.42".as(Crystal::Dbus::Native::Value)])
      sig_msg.serialize(server)

      reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 51_u32, reply_serial: req.serial)
      reply.encode_body("s", ["bus-id-999".as(Crystal::Dbus::Native::Value)])
      reply.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    reply = conn.call(
      destination: "org.freedesktop.DBus",
      path: "/org/freedesktop/DBus",
      interface: "org.freedesktop.DBus",
      member: "GetId",
      signature: "s",
      values: ["arg1".as(Crystal::Dbus::Native::Value)]
    )
    reply.decode_body.should eq(["bus-id-999".as(Crystal::Dbus::Native::Value)])

    if sig = conn.poll_signal
      sig.member.should eq("NameAcquired")
      sig.decode_body.should eq([":1.42".as(Crystal::Dbus::Native::Value)])
    else
      fail("Expected buffered signal message")
    end
    conn.poll_signal.should be_nil
    conn.close
  end

  it "raises DBusError when call receives an Error or send uses unnegotiated FDs" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      req = Crystal::Dbus::Native::DBusMessage.parse(server)
      err = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::Error,
        60_u32
      )
      err.reply_serial = req.serial
      err.error_name = "org.freedesktop.DBus.Error.AccessDenied"
      err.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    msg = Crystal::Dbus::Native::DBusMessage.method_call(1_u32, "/org/test", "org.test", "Ping")
    expect_raises(Crystal::Dbus::Native::DBusError, "UNIX FD passing was not negotiated") do
      conn.send(msg, [0])
    end
    expect_raises(Crystal::Dbus::Native::DBusError, "AccessDenied") do
      conn.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames")
    end
    conn.close
  end

  it "sends and receives messages with file descriptors when negotiated" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    server.read_buffering = false
    pipe_r, pipe_w = IO.pipe
    spawn do
      server.read_byte
      server.gets("\r\n")
      server << "OK fedcba0987654321\r\n"
      server.flush
      server.gets("\r\n")
      server << "AGREE_UNIX_FD\r\n"
      server.flush
      server.gets("\r\n")

      server_conn = Crystal::Dbus::Native::DBusConnection.new(server)
      msg, fds = server_conn.receive_with_fds
      msg.unix_fds.should eq(1_u32)
      fds.size.should eq(1)
      LibC.write(fds[0], "secret-fd".to_unsafe, 9)
      LibC.close(fds[0])
      server_conn.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    conn.start(1000_u32, authenticate: true, hello: false, negotiate_unix_fd: true)
    conn.unix_fd_negotiated?.should be_true

    call_msg = Crystal::Dbus::Native::DBusMessage.method_call(
      serial: conn.next_serial,
      path: "/org/test/FD",
      interface: "org.test.FD",
      member: "SendPipe"
    )
    call_msg.encode_body("h", [Crystal::Dbus::Native::UnixFD.new(0_u32).as(Crystal::Dbus::Native::Value)])
    conn.send(call_msg, [pipe_w.fd])
    pipe_w.close

    pipe_r.gets_to_end.should eq("secret-fd")
    pipe_r.close
    conn.close
  end
end
