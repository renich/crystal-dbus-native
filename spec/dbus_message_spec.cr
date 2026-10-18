require "./spec_helper"
require "socket"

# Verifies [FUNC-003] / [TECH-002], [TECH-005]
private def send_raw_header(
  server : UNIXSocket,
  endian : UInt8,
  msg_type : UInt8,
  version : UInt8,
  body_len : UInt32,
  serial : UInt32,
  fields_slice : Bytes = Bytes.empty,
) : Nil
  header = IO::Memory.new
  header.write_byte(endian)
  header.write_byte(msg_type)
  header.write_byte(0_u8)
  header.write_byte(version)
  header.write_bytes(body_len, IO::ByteFormat::LittleEndian)
  header.write_bytes(serial, IO::ByteFormat::LittleEndian)
  header.write_bytes(fields_slice.size.to_u32, IO::ByteFormat::LittleEndian)
  header.write(fields_slice) unless fields_slice.empty?
  server.write(header.to_slice)
  server.flush
  server.close
end

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
      spawn { send_raw_header(server, 'z'.ord.to_u8, 1_u8, 1_u8, 0_u32, 1_u32) }
      expect_raises(Crystal::Dbus::Native::MessageError, "Invalid endianness byte") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception when message serial is zero" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn { send_raw_header(server, 'l'.ord.to_u8, 1_u8, 1_u8, 0_u32, 0_u32) }
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
        send_raw_header(server, 'l'.ord.to_u8, 1_u8, 1_u8, 0_u32, 1_u32, fields.to_slice)
      end

      expect_raises(Crystal::Dbus::Native::MessageError, "Unknown or invalid header field code") do
        Crystal::Dbus::Native::DBusMessage.parse(client)
      end
      client.close
    end

    it "raises exception if total size exceeds max_size" do
      client, server = UNIXSocket.pair(Socket::Type::STREAM)
      spawn { send_raw_header(server, 'l'.ord.to_u8, 1_u8, 1_u8, 128_u32, 42_u32) }
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

    it "raises exception on unknown message type or unsupported protocol version" do
      client1, server1 = UNIXSocket.pair(Socket::Type::STREAM)
      spawn { send_raw_header(server1, 'l'.ord.to_u8, 99_u8, 1_u8, 0_u32, 1_u32) }
      expect_raises(Crystal::Dbus::Native::MessageError, "Unknown message type") do
        Crystal::Dbus::Native::DBusMessage.parse(client1)
      end
      client1.close

      client2, server2 = UNIXSocket.pair(Socket::Type::STREAM)
      spawn { send_raw_header(server2, 'l'.ord.to_u8, 1_u8, 2_u8, 0_u32, 1_u32) }
      expect_raises(Crystal::Dbus::Native::MessageError, "Unsupported D-Bus protocol version") do
        Crystal::Dbus::Native::DBusMessage.parse(client2)
      end
      client2.close
    end

    it "raises ProtocolError on non-zero alignment padding between header fields" do
      msg = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::MethodCall,
        1_u32
      )
      # First field: SIGNATURE = "s" (code=8, sig_len=1, 'g', 0, len=1, 's', 0 -> 7 bytes)
      # Followed by 1 byte of 8-byte alignment padding before second field, set to non-zero 0xff
      raw_fields = Bytes[8_u8, 1_u8, 'g'.ord.to_u8, 0_u8, 1_u8, 's'.ord.to_u8, 0_u8, 0xff_u8, 5_u8]
      expect_raises(Crystal::Dbus::Native::ProtocolError, "Non-zero header alignment padding") do
        Crystal::Dbus::Native::HeaderCodec.parse_fields(msg, raw_fields, IO::ByteFormat::LittleEndian)
      end
    end
  end
end
