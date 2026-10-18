require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::DBusMessage do
  describe ".parse and #serialize" do
    it "round-trips a method call with header fields and body" do
      body_payload = "hello world".to_slice
      msg = Crystal::Dbus::Native::DBusMessage.method_call(
        serial: 42_u32,
        path: "/org/test/Object",
        interface: "org.test.Interface",
        member: "TestMethod",
        destination: "org.test.Destination",
        signature: "s",
        body: body_payload
      )

      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        msg.serialize(server)
        server.flush
        server.close
      end

      parsed = Crystal::Dbus::Native::DBusMessage.parse(client)
      client.close

      parsed.endian.should eq(Crystal::Dbus::Native::Endianness::Little)
      parsed.message_type.should eq(Crystal::Dbus::Native::MessageType::MethodCall)
      parsed.serial.should eq(42_u32)
      parsed.body_length.should eq(body_payload.size.to_u32)
      parsed.path.should eq("/org/test/Object")
      parsed.interface.should eq("org.test.Interface")
      parsed.member.should eq("TestMethod")
      parsed.destination.should eq("org.test.Destination")
      parsed.signature.should eq("s")
      parsed.body.should eq(body_payload)
    end

    it "round-trips a method return message with UNIX_FDS and BigEndian encoding" do
      body_payload = Bytes[0, 0, 0, 3, 'f'.ord.to_u8, 'o'.ord.to_u8, 'o'.ord.to_u8, 0]
      msg = Crystal::Dbus::Native::DBusMessage.method_return(
        serial: 101_u32,
        reply_serial: 42_u32,
        destination: ":1.99",
        signature: "s",
        body: body_payload
      )
      msg.endian = Crystal::Dbus::Native::Endianness::Big
      msg.unix_fds = 2_u32

      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        msg.serialize(server)
        server.flush
        server.close
      end

      parsed = Crystal::Dbus::Native::DBusMessage.parse(client)
      client.close

      parsed.endian.should eq(Crystal::Dbus::Native::Endianness::Big)
      parsed.message_type.should eq(Crystal::Dbus::Native::MessageType::MethodReturn)
      parsed.serial.should eq(101_u32)
      parsed.reply_serial.should eq(42_u32)
      parsed.unix_fds.should eq(2_u32)
      parsed.destination.should eq(":1.99")
      parsed.signature.should eq("s")
      parsed.body.should eq(body_payload)
      parsed.read_string_body.should eq("foo")
    end

    it "raises exception on invalid endianness byte" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        header = IO::Memory.new
        header.write_byte('z'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Invalid endianness byte") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception when message serial is zero" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Invalid message serial: 0") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception on unknown header field code" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        fields = IO::Memory.new
        fields.write_byte(99_u8)
        fields.write_byte(1_u8)
        fields.write_byte('u'.ord.to_u8)
        fields.write_byte(0_u8)
        fields.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
        fields_slice = fields.to_slice

        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(fields_slice.size.to_u32, IO::ByteFormat::LittleEndian)
        header.write(fields_slice)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Unknown or invalid header field code") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception if total size exceeds max_size" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(128_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(42_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Message length exceeds maximum") do
        Crystal::Dbus::Native::DBusMessage.parse(client, 100_u32)
      end
      client.close
    end

    it "raises on premature connection close" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        server.write(Bytes[1, 2, 3])
        server.close
      end

      expect_raises(Crystal::Dbus::Native::ConnectionClosedError, "Connection closed") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception on unknown message type" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(99_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Unknown message type") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception on unsupported protocol version" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn do
        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(2_u8)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
        server.write(header.to_slice)
        server.flush
        server.close
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Unsupported D-Bus protocol version") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end
  end
end
