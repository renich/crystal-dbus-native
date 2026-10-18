module Crystal::Dbus::Native
  # Standard D-Bus header field codes.
  module HeaderField
    # Object path (`o`) target of a method call or source of a signal.
    PATH = 1_u8
    # Interface name (`s`) of a method call or signal.
    INTERFACE = 2_u8
    # Member (method or signal) name (`s`).
    MEMBER = 3_u8
    # Error name (`s`) of an error message.
    ERROR_NAME = 4_u8
    # Serial number (`u`) of the message this message replies to.
    REPLY_SERIAL = 5_u8
    # Bus name (`s`) of the intended recipient connection.
    DESTINATION = 6_u8
    # Unique bus name (`s`) of the sending connection.
    SENDER = 7_u8
    # Type signature (`g`) of the message body payload.
    SIGNATURE = 8_u8
    # Number of UNIX file descriptors (`u`) accompanying the message.
    UNIX_FDS = 9_u8
  end

  # Encodes and decodes D-Bus wire header field arrays (`a(yv)`).
  module HeaderCodec
    # Parses the serialized header field array `data` and populates fields on `msg`.
    def self.parse_fields(msg : DBusMessage, data : Bytes, format : IO::ByteFormat) : Nil
      fio = IO::Memory.new(data)
      while fio.pos < data.size
        align_read(fio, 8)
        break if fio.pos >= data.size

        field_code = fio.read_byte || break
        var_sig = read_variant_signature(fio)
        validate_field_signature(field_code, var_sig)
        apply_field(msg, field_code, fio, format)
      end
    rescue IO::EOFError
      raise MessageError.new("Unexpected EOF in header fields")
    end

    # Serializes all populated header fields of `msg` to `io` using `format`.
    def self.write_fields(msg : DBusMessage, io : IO, format : IO::ByteFormat) : Nil
      write_str_field(io, HeaderField::PATH, msg.path, 'o', format)
      write_str_field(io, HeaderField::INTERFACE, msg.interface, 's', format)
      write_str_field(io, HeaderField::MEMBER, msg.member, 's', format)
      write_str_field(io, HeaderField::ERROR_NAME, msg.error_name, 's', format)
      write_str_field(io, HeaderField::DESTINATION, msg.destination, 's', format)
      write_str_field(io, HeaderField::SENDER, msg.sender, 's', format)
      write_signature_field(io, msg.signature)
      write_uint32_field(io, HeaderField::REPLY_SERIAL, msg.reply_serial, format)
      write_uint32_field(io, HeaderField::UNIX_FDS, msg.unix_fds, format)
    end

    # Reads a 4-byte aligned, length-prefixed, NUL-terminated UTF-8 string from `io`.
    def self.read_string_field(io : IO::Memory, format : IO::ByteFormat) : String
      align_read(io, 4)
      len = io.read_bytes(UInt32, format)
      if len.to_u64 + 1 > (io.size - io.pos).to_u64
        raise MessageError.new("String length exceeds remaining buffer")
      end
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      raise MessageError.new("Missing NUL terminator in string") unless io.read_byte == 0_u8
      raise MessageError.new("Embedded NUL byte in string") if buf.includes?(0_u8)
      str = String.new(buf)
      raise MessageError.new("Invalid UTF-8 in string") unless str.valid_encoding?
      str
    end

    # Reads and validates a D-Bus object path (`o`) from `io`.
    def self.read_object_path_field(io : IO::Memory, format : IO::ByteFormat) : String
      path = read_string_field(io, format)
      raise MessageError.new("Object path must start with '/'") unless path.starts_with?('/')
      path
    end

    # Reads and validates a 1-byte length-prefixed, NUL-terminated D-Bus signature (`g`) from `io`.
    def self.read_signature_field(io : IO::Memory) : String
      len = io.read_byte || raise MessageError.new("Unexpected EOF reading signature")
      if len.to_u64 + 1 > (io.size - io.pos).to_u64
        raise MessageError.new("Signature length exceeds remaining buffer")
      end
      buf = Bytes.new(len.to_i)
      io.read_fully(buf)
      raise MessageError.new("Missing NUL terminator in signature") unless io.read_byte == 0_u8
      raise MessageError.new("Embedded NUL byte in signature") if buf.includes?(0_u8)
      sig = String.new(buf)
      raise MessageError.new("Invalid UTF-8 in signature") unless sig.valid_encoding?
      SignatureValidator.validate(sig)
      sig
    end

    private def self.read_variant_signature(fio : IO::Memory) : String
      var_sig_len = fio.read_byte || raise MessageError.new("Unexpected EOF reading variant signature length")
      if var_sig_len.to_u64 + 1 > (fio.size - fio.pos).to_u64
        raise MessageError.new("Variant signature length exceeds header buffer")
      end
      var_sig_bytes = Bytes.new(var_sig_len.to_i)
      fio.read_fully(var_sig_bytes)
      raise MessageError.new("Missing NUL terminator in variant signature") unless fio.read_byte == 0_u8
      String.new(var_sig_bytes)
    end

    private def self.validate_field_signature(code : UInt8, var_sig : String) : Nil
      expected = case code
                 when HeaderField::PATH                                then "o"
                 when HeaderField::SIGNATURE                           then "g"
                 when HeaderField::REPLY_SERIAL, HeaderField::UNIX_FDS then "u"
                 when HeaderField::INTERFACE, HeaderField::MEMBER,
                      HeaderField::ERROR_NAME, HeaderField::DESTINATION,
                      HeaderField::SENDER
                   "s"
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

    private def self.write_str_field(io : IO, code : UInt8, val : String?, kind : Char, fmt : IO::ByteFormat) : Nil
      return unless val
      raise MessageError.new("Header string field contains embedded NUL byte") if val.to_slice.includes?(0_u8)
      align_write(io, 8)
      io.write_byte(code)
      io.write_byte(1_u8)
      io.write_byte(kind.ord.to_u8)
      io.write_byte(0_u8)
      align_write(io, 4)
      fmt.encode(val.bytesize.to_u32, io)
      io.write(val.to_slice)
      io.write_byte(0_u8)
    end

    private def self.write_signature_field(io : IO, sig : String?) : Nil
      return unless sig
      SignatureValidator.validate(sig)
      align_write(io, 8)
      io.write_byte(HeaderField::SIGNATURE)
      io.write_byte(1_u8)
      io.write_byte('g'.ord.to_u8)
      io.write_byte(0_u8)
      io.write_byte(sig.bytesize.to_u8)
      io.write(sig.to_slice)
      io.write_byte(0_u8)
    end

    private def self.write_uint32_field(io : IO, code : UInt8, val : UInt32?, format : IO::ByteFormat) : Nil
      return unless val
      align_write(io, 8)
      io.write_byte(code)
      io.write_byte(1_u8)
      io.write_byte('u'.ord.to_u8)
      io.write_byte(0_u8)
      align_write(io, 4)
      format.encode(val, io)
    end

    private def self.read_uint32_field(io : IO::Memory, format : IO::ByteFormat) : UInt32
      align_read(io, 4)
      io.read_bytes(UInt32, format)
    end

    private def self.align_read(io : IO::Memory, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.read_byte }
    end

    # Writes zero padding bytes to `io` until `io.pos` is a multiple of `alignment`.
    def self.align_write(io : IO, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times { io.write_byte(0_u8) }
    end
  end
end
