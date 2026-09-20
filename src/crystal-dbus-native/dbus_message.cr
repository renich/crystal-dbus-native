require "socket"

module Crystal::Dbus::Native
  enum Endianness : UInt8
    Little = 0x6c_u8 # 'l'
    Big    = 0x42_u8 # 'B'
  end

  enum MessageType : UInt8
    MethodCall   = 1_u8
    MethodReturn = 2_u8
    Error        = 3_u8
    Signal       = 4_u8
  end

  module HeaderField
    PATH         = 1_u8
    INTERFACE    = 2_u8
    MEMBER       = 3_u8
    ERROR_NAME   = 4_u8
    REPLY_SERIAL = 5_u8
    DESTINATION  = 6_u8
    SENDER       = 7_u8
    SIGNATURE    = 8_u8
    UNIX_FDS     = 9_u8
  end

  class DBusMessage
    property endian : Endianness
    property message_type : MessageType
    property flags : UInt8
    property protocol_version : UInt8
    property body_length : UInt32
    property serial : UInt32

    property path : String?
    property interface : String?
    property member : String?
    property error_name : String?
    property reply_serial : UInt32?
    property destination : String?
    property sender : String?
    property signature : String?
    property unix_fds : UInt32?

    property body : Bytes

    def initialize(
      @endian : Endianness,
      @message_type : MessageType,
      @serial : UInt32,
      @flags : UInt8 = 0_u8,
      @protocol_version : UInt8 = 1_u8,
      @body_length : UInt32 = 0_u32,
      @body : Bytes = Bytes.empty,
    )
    end

    def self.method_call(
      serial : UInt32,
      path : String,
      interface : String,
      member : String,
      destination : String? = nil,
      signature : String? = nil,
      body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodCall, serial, body_length: body.size.to_u32, body: body)
      msg.path = path
      msg.interface = interface
      msg.member = member
      msg.destination = destination
      msg.signature = signature
      msg
    end

    def self.method_return(
      serial : UInt32,
      reply_serial : UInt32,
      destination : String? = nil,
      signature : String? = nil,
      body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodReturn, serial, body_length: body.size.to_u32, body: body)
      msg.reply_serial = reply_serial
      msg.destination = destination
      msg.signature = signature
      msg
    end

    def self.parse(io : IO, max_size : UInt32 = 134_217_728_u32) : self
      header = Bytes.new(16)
      begin
        io.read_fully(header)
      rescue IO::EOFError
        raise ConnectionClosedError.new("Connection closed reading fixed message header")
      end

      endian_char = header[0].chr
      format = (endian_char == 'l') ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      endian_sym = (endian_char == 'l') ? Endianness::Little : Endianness::Big

      msg_type_byte = header[1]
      msg_type = MessageType.from_value?(msg_type_byte) || raise MessageError.new("Unknown message type: #{msg_type_byte}")

      flags = header[2]
      version = header[3]
      raise MessageError.new("Unsupported D-Bus protocol version: #{version}") unless version == 1_u8

      body_len = format.decode(UInt32, header[4, 4])
      serial = format.decode(UInt32, header[8, 4])
      fields_len = format.decode(UInt32, header[12, 4])

      if body_len.to_u64 + fields_len.to_u64 > max_size.to_u64
        raise MessageError.new("Message length exceeds maximum allowed limit")
      end

      fields_data = Bytes.new(fields_len.to_i)
      io.read_fully(fields_data) if fields_len > 0

      pad_len = (8 - ((16 + fields_len) % 8)) % 8
      if pad_len > 0
        padding = Bytes.new(pad_len.to_i)
        io.read_fully(padding)
      end

      body_data = Bytes.new(body_len.to_i)
      io.read_fully(body_data) if body_len > 0

      msg = new(endian_sym, msg_type, serial, flags, version, body_len, body_data)
      parse_fields(msg, fields_data, format) if fields_len > 0
      msg
    end

    def serialize(io : IO) : Nil
      format = (@endian == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      fields_mem = IO::Memory.new
      write_fields(fields_mem, format)
      fields_bytes = fields_mem.to_slice

      io.write_byte(@endian.value)
      io.write_byte(@message_type.value)
      io.write_byte(@flags)
      io.write_byte(@protocol_version)
      format.encode(@body.size.to_u32, io)
      format.encode(@serial, io)
      format.encode(fields_bytes.size.to_u32, io)

      io.write(fields_bytes)

      pad_len = (8 - ((16 + fields_bytes.size) % 8)) % 8
      pad_len.times { io.write_byte(0_u8) }

      io.write(@body) if @body.size > 0
    end

    def to_slice : Bytes
      mem = IO::Memory.new
      serialize(mem)
      mem.to_slice
    end

    private def self.parse_fields(msg : DBusMessage, data : Bytes, format : IO::ByteFormat) : Nil
      fio = IO::Memory.new(data)
      while fio.pos < data.size
        align_io(fio, 8)
        break if fio.pos >= data.size

        field_code = fio.read_byte || break
        var_sig_len = fio.read_byte || break
        var_sig_bytes = Bytes.new(var_sig_len.to_i)
        fio.read_fully(var_sig_bytes)
        fio.read_byte # NUL terminator of signature

        apply_field(msg, field_code, fio, format)
      end
    end

    private def self.apply_field(msg : DBusMessage, code : UInt8, fio : IO, format : IO::ByteFormat) : Nil
      case code
      when HeaderField::PATH         then msg.path = read_string_field(fio, format)
      when HeaderField::INTERFACE    then msg.interface = read_string_field(fio, format)
      when HeaderField::MEMBER       then msg.member = read_string_field(fio, format)
      when HeaderField::ERROR_NAME   then msg.error_name = read_string_field(fio, format)
      when HeaderField::DESTINATION  then msg.destination = read_string_field(fio, format)
      when HeaderField::SENDER       then msg.sender = read_string_field(fio, format)
      when HeaderField::SIGNATURE    then msg.signature = read_signature_field(fio)
      when HeaderField::REPLY_SERIAL then msg.reply_serial = read_uint32_field(fio, format)
      when HeaderField::UNIX_FDS     then msg.unix_fds = read_uint32_field(fio, format)
      end
    end

    private def write_fields(io : IO, format : IO::ByteFormat) : Nil
      write_str_field(io, HeaderField::PATH, @path, 'o', format) if @path
      write_str_field(io, HeaderField::INTERFACE, @interface, 's', format) if @interface
      write_str_field(io, HeaderField::MEMBER, @member, 's', format) if @member
      write_str_field(io, HeaderField::ERROR_NAME, @error_name, 's', format) if @error_name
      write_str_field(io, HeaderField::DESTINATION, @destination, 's', format) if @destination
      write_str_field(io, HeaderField::SENDER, @sender, 's', format) if @sender

      if sig = @signature
        align_io(io, 8)
        io.write_byte(HeaderField::SIGNATURE)
        io.write_byte(1_u8) # Variant signature length
        io.write_byte('g'.ord.to_u8)
        io.write_byte(0_u8)
        io.write_byte(sig.bytesize.to_u8)
        io.write(sig.to_slice)
        io.write_byte(0_u8)
      end

      if rep = @reply_serial
        align_io(io, 8)
        io.write_byte(HeaderField::REPLY_SERIAL)
        io.write_byte(1_u8)
        io.write_byte('u'.ord.to_u8)
        io.write_byte(0_u8)
        align_io(io, 4)
        format.encode(rep, io)
      end
    end

    private def write_str_field(io : IO, code : UInt8, val : String?, sig_type : Char, format : IO::ByteFormat) : Nil
      return unless val
      align_io(io, 8)
      io.write_byte(code)
      io.write_byte(1_u8)
      io.write_byte(sig_type.ord.to_u8)
      io.write_byte(0_u8)
      align_io(io, 4)
      format.encode(val.bytesize.to_u32, io)
      io.write(val.to_slice)
      io.write_byte(0_u8)
    end

    private def self.read_string_field(io : IO, format : IO::ByteFormat) : String
      align_io(io, 4)
      len = io.read_bytes(UInt32, format)
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      io.read_byte # NUL
      String.new(buf)
    end

    private def self.read_signature_field(io : IO) : String
      len = io.read_byte || 0_u8
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      io.read_byte # NUL
      String.new(buf)
    end

    private def self.read_uint32_field(io : IO, format : IO::ByteFormat) : UInt32
      align_io(io, 4)
      io.read_bytes(UInt32, format)
    end

    private def self.align_io(io : IO, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.read_byte }
    end

    private def align_io(io : IO, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.write_byte(0_u8) }
    end
  end
end
