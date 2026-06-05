require "./spec_helper"
require "socket"

describe Crystal::Dbus::Native::DBusMessage do
  describe ".parse" do
    it "parses a valid little-endian header" do
      server = UNIXServer.new("/tmp/test_dbus_msg.sock")
      begin
        client = UNIXSocket.new("/tmp/test_dbus_msg.sock")
        conn = server.accept

        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(12_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(42_u32, IO::ByteFormat::LittleEndian)

        conn.write(header.to_slice)
        conn.flush

        msg = Crystal::Dbus::Native::DBusMessage.parse(client)
        msg.endian.should eq(Crystal::Dbus::Native::Endianness::Little)
        msg.body_length.should eq(12)
        msg.serial.should eq(42)

        client.close
        conn.close
      ensure
        File.delete("/tmp/test_dbus_msg.sock") if File.exists?("/tmp/test_dbus_msg.sock")
      end
    end

    it "raises exception if total size exceeds max_size" do
      server = UNIXServer.new("/tmp/test_dbus_msg_large.sock")
      begin
        client = UNIXSocket.new("/tmp/test_dbus_msg_large.sock")
        conn = server.accept

        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(128_u32, IO::ByteFormat::LittleEndian)
        header.write_bytes(42_u32, IO::ByteFormat::LittleEndian)

        conn.write(header.to_slice)
        conn.flush

        expect_raises(Crystal::Dbus::Native::MessageError, "exceeds max") do
          Crystal::Dbus::Native::DBusMessage.parse(client, 100)
        end

        client.close
        conn.close
      ensure
        File.delete("/tmp/test_dbus_msg_large.sock") if File.exists?("/tmp/test_dbus_msg_large.sock")
      end
    end

    it "raises on premature connection close" do
      server = UNIXServer.new("/tmp/test_dbus_msg_close.sock")
      begin
        client = UNIXSocket.new("/tmp/test_dbus_msg_close.sock")
        conn = server.accept

        conn.write(Bytes[1, 2, 3])
        conn.close

        expect_raises(Crystal::Dbus::Native::ConnectionClosedError, "Connection closed") do
          Crystal::Dbus::Native::DBusMessage.parse(client)
        end
        client.close
      ensure
        File.delete("/tmp/test_dbus_msg_close.sock") if File.exists?("/tmp/test_dbus_msg_close.sock")
      end
    end

    it "raises exception on integer overflow of body_length" do
      server = UNIXServer.new("/tmp/test_dbus_msg_overflow.sock")
      begin
        client = UNIXSocket.new("/tmp/test_dbus_msg_overflow.sock")
        conn = server.accept

        header = IO::Memory.new
        header.write_byte('l'.ord.to_u8)
        header.write_byte(1_u8)
        header.write_byte(0_u8)
        header.write_byte(1_u8)
        header.write_bytes(UInt32::MAX - 5, IO::ByteFormat::LittleEndian)
        header.write_bytes(42_u32, IO::ByteFormat::LittleEndian)

        conn.write(header.to_slice)
        conn.flush

        expect_raises(Crystal::Dbus::Native::MessageError, "exceeds max") do
          Crystal::Dbus::Native::DBusMessage.parse(client, 100)
        end

        client.close
        conn.close
      ensure
        File.delete("/tmp/test_dbus_msg_overflow.sock") if File.exists?("/tmp/test_dbus_msg_overflow.sock")
      end
    end
  end
end
