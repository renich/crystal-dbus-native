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

      name = ":1.123"
      body_mem = IO::Memory.new
      IO::ByteFormat::LittleEndian.encode(name.bytesize.to_u32, body_mem)
      body_mem.write(name.to_slice)
      body_mem.write_byte(0_u8)

      reply = Crystal::Dbus::Native::DBusMessage.method_return(
        serial: 10_u32,
        reply_serial: msg.serial,
        destination: name,
        signature: "s",
        body: body_mem.to_slice
      )
      reply.serialize(server)
      server.flush
      server.close
    end

    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    unique_name = conn.start(1000_u32)
    unique_name.should eq(":1.123")
    conn.unique_name.should eq(":1.123")
    conn.server_guid.should eq("1234567890abcdef")

    conn.close
    client.closed?.should be_true
  end

  it "raises DBusError when Hello reply is an Error or malformed" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    spawn do
      msg = Crystal::Dbus::Native::DBusMessage.parse(server)
      msg.member.should eq("Hello")

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
    serials.size.should eq(10)
    serials.uniq.size.should eq(10)

    conn.close
    server.close
  end
end
