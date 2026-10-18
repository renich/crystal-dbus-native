require "socket"

module Crystal::Dbus::Native
  # Byte-order encoding for D-Bus wire messages.
  enum Endianness : UInt8
    Little = 0x6c_u8 # 'l'
    Big    = 0x42_u8 # 'B'
  end

  # D-Bus message types defined by the wire protocol specification.
  enum MessageType : UInt8
    MethodCall   = 1_u8
    MethodReturn = 2_u8
    Error        = 3_u8
    Signal       = 4_u8
  end

  # Standard D-Bus header field codes.
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

  # Represents a framed D-Bus wire protocol message with header fields and payload body.
  class DBusMessage
    property endian : Endianness
    property message_type : MessageType
    property flags : UInt8
    property protocol_version : UInt8
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

    # Creates a new `DBusMessage` instance.
    def initialize(
      @endian : Endianness,
      @message_type : MessageType,
      @serial : UInt32,
      @flags : UInt8 = 0_u8,
      @protocol_version : UInt8 = 1_u8,
      @body : Bytes = Bytes.empty,
    ) : Nil
    end

    # Returns the byte length of the message body payload.
    def body_length : UInt32
      @body.size.to_u32
    end

    # Constructs a D-Bus `MethodCall` message.
    def self.method_call(
      serial : UInt32,
      path : String,
      interface : String,
      member : String,
      destination : String? = nil,
      signature : String? = nil,
      body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodCall, serial, body: body)
      msg.path = path
      msg.interface = interface
      msg.member = member
      msg.destination = destination
      msg.signature = signature
      msg
    end

    # Constructs a D-Bus `MethodReturn` message.
    def self.method_return(
      serial : UInt32,
      reply_serial : UInt32,
      destination : String? = nil,
      signature : String? = nil,
      body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodReturn, serial, body: body)
      msg.reply_serial = reply_serial
      msg.destination = destination
      msg.signature = signature
      msg
    end

    # Parses a D-Bus message from the given `IO` stream, enforcing `max_size` limits.
    def self.parse(io : IO, max_size : UInt32 = 134_217_728_u32) : self
      header_buf = uninitialized StaticArray(UInt8, 16)
      header = header_buf.to_slice
      begin
        io.read_fully(header)
      rescue IO::EOFError
        raise ConnectionClosedError.new("Connection closed reading fixed message header")
      end

      endian_sym = Endianness.from_value?(header[0]) ||
                   raise MessageError.new("Invalid endianness byte: #{header[0]}")
      format = (endian_sym == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      msg_type = MessageType.from_value?(header[1]) ||
                 raise MessageError.new("Unknown message type: #{header[1]}")

      flags = header[2]
      version = header[3]
      raise MessageError.new("Unsupported D-Bus protocol version: #{version}") unless version == 1_u8

      body_len = format.decode(UInt32, header[4, 4])
      serial = format.decode(UInt32, header[8, 4])
      raise MessageError.new("Invalid message serial: 0") if serial == 0_u32
      fields_len = format.decode(UInt32, header[12, 4])

      if body_len.to_u64 + fields_len.to_u64 > max_size.to_u64
        raise MessageError.new("Message length exceeds maximum allowed limit")
      end

      fields_data, body_data = read_payload(io, fields_len, body_len)
      msg = new(endian_sym, msg_type, serial, flags: flags, protocol_version: version, body: body_data)
      parse_fields(msg, fields_data, format) if fields_len > 0
      msg
    end

    # Serializes this message in D-Bus wire format to `io`.
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

    # Returns the serialized wire representation of this message as `Bytes`.
    def to_slice : Bytes
      mem = IO::Memory.new
      serialize(mem)
      mem.to_slice
    end

    # Decodes the first length-prefixed UTF-8 string from the message body using the message's endianness.
    def read_string_body : String
      raise MessageError.new("Message body too short for string length") if @body.size < 4
      format = (@endian == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      name_len = format.decode(UInt32, @body[0, 4])
      unless 4_u64 + name_len.to_u64 <= @body.size.to_u64
        raise MessageError.new("String body length exceeds payload bounds")
      end
      String.new(@body[4, name_len.to_i])
    end

    private def self.read_payload(io : IO, fields_len : UInt32, body_len : UInt32) : Tuple(Bytes, Bytes)
      fields_data = Bytes.new(fields_len.to_i)
      io.read_fully(fields_data) if fields_len > 0

      pad_len = (8 - ((16 + fields_len) % 8)) % 8
      if pad_len > 0
        padding_buf = uninitialized StaticArray(UInt8, 8)
        padding = padding_buf.to_slice[0, pad_len.to_i]
        io.read_fully(padding)
        raise MessageError.new("Non-zero header alignment padding") unless padding.all?(&.zero?)
      end

      body_data = Bytes.new(body_len.to_i)
      io.read_fully(body_data) if body_len > 0
      {fields_data, body_data}
    rescue IO::EOFError
      raise MessageError.new("Unexpected EOF reading message")
    end

    private def self.parse_fields(msg : DBusMessage, data : Bytes, format : IO::ByteFormat) : Nil
      fio = IO::Memory.new(data)
      while fio.pos < data.size
        align_io(fio, 8)
        break if fio.pos >= data.size

        field_code = fio.read_byte || break
        var_sig_len = fio.read_byte || raise MessageError.new("Unexpected EOF reading variant signature length")
        if var_sig_len.to_u64 + 1 > (fio.size - fio.pos).to_u64
          raise MessageError.new("Variant signature length exceeds header buffer")
        end
        var_sig_bytes = Bytes.new(var_sig_len.to_i)
        fio.read_fully(var_sig_bytes)
        nul = fio.read_byte
        raise MessageError.new("Missing NUL terminator in variant signature") unless nul == 0_u8

        validate_field_signature(field_code, String.new(var_sig_bytes))
        apply_field(msg, field_code, fio, format)
      end
    rescue IO::EOFError
      raise MessageError.new("Unexpected EOF in header fields")
    end

    private def self.validate_field_signature(code : UInt8, var_sig : String) : Nil
      expected = case code
                 when HeaderField::PATH
                   "o"
                 when HeaderField::INTERFACE, HeaderField::MEMBER, HeaderField::ERROR_NAME,
                      HeaderField::DESTINATION, HeaderField::SENDER
                   "s"
                 when HeaderField::SIGNATURE
                   "g"
                 when HeaderField::REPLY_SERIAL, HeaderField::UNIX_FDS
                   "u"
                 else
                   raise MessageError.new("Unknown or invalid header field code: #{code}")
                 end

      return if var_sig == expected
      raise MessageError.new("Invalid variant signature '#{var_sig}' for field #{code}, expected '#{expected}'")
    end

    private def self.apply_field(msg : DBusMessage, code : UInt8, fio : IO::Memory, format : IO::ByteFormat) : Nil
      case code
      when HeaderField::PATH         then msg.path = read_object_path_field(fio, format)
      when HeaderField::SIGNATURE    then msg.signature = read_signature_field(fio)
      when HeaderField::REPLY_SERIAL then msg.reply_serial = read_uint32_field(fio, format)
      when HeaderField::UNIX_FDS     then msg.unix_fds = read_uint32_field(fio, format)
      else
        apply_string_field(msg, code, read_string_field(fio, format))
      end
    end

    private def self.apply_string_field(msg : DBusMessage, code : UInt8, value : String) : Nil
      case code
      when HeaderField::INTERFACE   then msg.interface = value
      when HeaderField::MEMBER      then msg.member = value
      when HeaderField::ERROR_NAME  then msg.error_name = value
      when HeaderField::DESTINATION then msg.destination = value
      when HeaderField::SENDER      then msg.sender = value
      else
        raise MessageError.new("Unknown or invalid header field code: #{code}")
      end
    end

    private def self.read_object_path_field(io : IO::Memory, format : IO::ByteFormat) : String
      path = read_string_field(io, format)
      raise MessageError.new("Object path must start with '/'") unless path.starts_with?('/')
      path
    end

    private def write_fields(io : IO, format : IO::ByteFormat) : Nil
      write_str_field(io, HeaderField::PATH, @path, 'o', format)
      write_str_field(io, HeaderField::INTERFACE, @interface, 's', format)
      write_str_field(io, HeaderField::MEMBER, @member, 's', format)
      write_str_field(io, HeaderField::ERROR_NAME, @error_name, 's', format)
      write_str_field(io, HeaderField::DESTINATION, @destination, 's', format)
      write_str_field(io, HeaderField::SENDER, @sender, 's', format)
      write_signature_field(io, @signature)
      write_uint32_field(io, HeaderField::REPLY_SERIAL, @reply_serial, format)
      write_uint32_field(io, HeaderField::UNIX_FDS, @unix_fds, format)
    end

    private def write_str_field(io : IO, code : UInt8, val : String?, sig_type : Char, format : IO::ByteFormat) : Nil
      return unless val
      raise MessageError.new("Header string field contains embedded NUL byte") if val.to_slice.includes?(0_u8)
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

    private def write_signature_field(io : IO, sig : String?) : Nil
      return unless sig
      SignatureValidator.validate(sig)
      align_io(io, 8)
      io.write_byte(HeaderField::SIGNATURE)
      io.write_byte(1_u8)
      io.write_byte('g'.ord.to_u8)
      io.write_byte(0_u8)
      io.write_byte(sig.bytesize.to_u8)
      io.write(sig.to_slice)
      io.write_byte(0_u8)
    end

    private def write_uint32_field(io : IO, code : UInt8, val : UInt32?, format : IO::ByteFormat) : Nil
      return unless val
      align_io(io, 8)
      io.write_byte(code)
      io.write_byte(1_u8)
      io.write_byte('u'.ord.to_u8)
      io.write_byte(0_u8)
      align_io(io, 4)
      format.encode(val, io)
    end

    private def self.read_string_field(io : IO::Memory, format : IO::ByteFormat) : String
      align_io(io, 4)
      len = io.read_bytes(UInt32, format)
      if len.to_u64 + 1 > (io.size - io.pos).to_u64
        raise MessageError.new("Header string length exceeds remaining buffer")
      end
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      nul = io.read_byte
      raise MessageError.new("Missing NUL terminator in string field") unless nul == 0_u8
      raise MessageError.new("Embedded NUL byte in string field") if buf.includes?(0_u8)
      str = String.new(buf)
      raise MessageError.new("Invalid UTF-8 in string field") unless str.valid_encoding?
      str
    end

    private def self.read_signature_field(io : IO::Memory) : String
      len = io.read_byte || raise MessageError.new("Unexpected EOF reading signature field")
      if len.to_u64 + 1 > (io.size - io.pos).to_u64
        raise MessageError.new("Signature field length exceeds remaining buffer")
      end
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      nul = io.read_byte
      raise MessageError.new("Missing NUL terminator in signature field") unless nul == 0_u8
      raise MessageError.new("Embedded NUL byte in signature field") if buf.includes?(0_u8)
      sig = String.new(buf)
      raise MessageError.new("Invalid UTF-8 in signature field") unless sig.valid_encoding?
      SignatureValidator.validate(sig)
      sig
    end

    private def self.read_uint32_field(io : IO::Memory, format : IO::ByteFormat) : UInt32
      align_io(io, 4)
      io.read_bytes(UInt32, format)
    end

    private def self.align_io(io : IO::Memory, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.read_byte }
    end

    private def align_io(io : IO, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.write_byte(0_u8) }
    end
  end
end
