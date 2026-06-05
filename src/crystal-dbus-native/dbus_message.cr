require "socket"

module Crystal::Dbus::Native
  enum Endianness
    Little
    Big
  end

  class DBusMessage
    property endian : Endianness
    property body_length : UInt32
    property serial : UInt32

    def initialize(@endian : Endianness, @body_length : UInt32, @serial : UInt32)
    end

    def self.parse(io : IO, max_size : UInt32 = 134_217_728_u32)
      header = Bytes.new(12)
      begin
        io.read_fully(header)
      rescue IO::EOFError
        raise ConnectionClosedError.new("Connection closed")
      end

      endian_char = header[0].chr
      if endian_char == 'l'
        endianness = IO::ByteFormat::LittleEndian
        endian_sym = Endianness::Little
      elsif endian_char == 'B'
        endianness = IO::ByteFormat::BigEndian
        endian_sym = Endianness::Big
      else
        raise MessageError.new("Invalid endianness: #{endian_char}")
      end

      body_length = endianness.decode(UInt32, header[4, 4])
      serial = endianness.decode(UInt32, header[8, 4])

      if body_length > max_size - 12_u32
        raise MessageError.new("exceeds max")
      end

      new(endian_sym, body_length, serial)
    end
  end
end
