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
      parsed.path.should eq("/org/test/Object")
      parsed.interface.should eq("org.test.Interface")
      parsed.member.should eq("TestMethod")
      parsed.destination.should eq("org.test.Destination")
      parsed.signature.should eq("s")
      parsed.body.should eq(body_payload)
    end

    it "round-trips a method return message" do
      body_payload = Bytes[1, 2, 3, 4]
      msg = Crystal::Dbus::Native::DBusMessage.method_return(
        serial: 101_u32,
        reply_serial: 42_u32,
        destination: ":1.99",
        signature: "ay",
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

      parsed.message_type.should eq(Crystal::Dbus::Native::MessageType::MethodReturn)
      parsed.serial.should eq(101_u32)
      parsed.reply_serial.should eq(42_u32)
      parsed.destination.should eq(":1.99")
      parsed.signature.should eq("ay")
      parsed.body.should eq(body_payload)
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
