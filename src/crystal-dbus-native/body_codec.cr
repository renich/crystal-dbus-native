module Crystal::Dbus::Native
  # General-purpose D-Bus wire body marshaler and unmarshaler supporting basic and nested container types.
  module BodyCodec
    # Encodes `values` according to the D-Bus type `signature` and `endian` byte order.
    def self.encode(signature : String, values : Array(Value), endian : Endianness = Endianness::Little) : Bytes
      types = SignatureValidator.split_types(signature)
      unless types.size == values.size
        raise MessageError.new("Value count (#{values.size}) does not match signature '#{signature}' (#{types.size})")
      end
      fmt = (endian == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      io = IO::Memory.new
      types.each_with_index { |type_sig, idx| encode_value(io, type_sig, values[idx], fmt) }
      io.to_slice
    end

    # Decodes `body` bytes into an array of `Value` items according to `signature` and `endian` byte order.
    def self.decode(signature : String, body : Bytes, endian : Endianness = Endianness::Little) : Array(Value)
      types = SignatureValidator.split_types(signature)
      return Array(Value).new if types.empty?
      fmt = (endian == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      io = IO::Memory.new(body)
      types.map { |type_sig| decode_value(io, type_sig, fmt) }
    rescue IO::EOFError
      raise MessageError.new("Unexpected EOF decoding message body")
    end

    # Returns the D-Bus wire alignment boundary (1, 2, 4, or 8 bytes) for a single complete type `sig`.
    def self.alignment_for(sig : String) : Int32
      case sig[0]
      when .in?("ygv")     then 1
      when .in?("nq")      then 2
      when .in?("biuhsoa") then 4
      when .in?("xtd({")   then 8
      else                      raise SignatureError.new("Unknown type code for alignment: #{sig[0]}")
      end
    end

    private def self.encode_value(io : IO::Memory, sig : String, val : Value, fmt : IO::ByteFormat) : Nil
      HeaderCodec.align_write(io, alignment_for(sig))
      case sig[0]
      when 'a'      then encode_array(io, sig[1..], val, fmt)
      when '('      then encode_struct(io, sig[1...-1], val, fmt)
      when 'v'      then encode_variant(io, val, fmt)
      when 's', 'o' then encode_string_like(io, sig[0], val, fmt)
      when 'g'      then write_sig_bytes(io, expect_type(val, Signature, 'g').value)
      else               encode_primitive(io, sig[0], val, fmt)
      end
    end

    private def self.encode_primitive(io : IO::Memory, code : Char, val : Value, fmt : IO::ByteFormat) : Nil
      case code
      when 'y' then io.write_byte(expect_type(val, UInt8, 'y'))
      when 'b' then fmt.encode(expect_type(val, Bool, 'b') ? 1_u32 : 0_u32, io)
      when 'n' then fmt.encode(expect_type(val, Int16, 'n'), io)
      when 'q' then fmt.encode(expect_type(val, UInt16, 'q'), io)
      when 'i' then fmt.encode(expect_type(val, Int32, 'i'), io)
      when 'u' then fmt.encode(expect_type(val, UInt32, 'u'), io)
      when 'h' then fmt.encode(expect_type(val, UnixFD, 'h').index, io)
      else          encode_wide_primitive(io, code, val, fmt)
      end
    end

    private def self.encode_wide_primitive(io : IO::Memory, code : Char, val : Value, fmt : IO::ByteFormat) : Nil
      case code
      when 'x' then fmt.encode(expect_type(val, Int64, 'x'), io)
      when 't' then fmt.encode(expect_type(val, UInt64, 't'), io)
      when 'd' then fmt.encode(expect_type(val, Float64, 'd'), io)
      else          raise SignatureError.new("Unsupported wide primitive type code: #{code}")
      end
    end

    private def self.encode_string_like(io : IO::Memory, code : Char, val : Value, fmt : IO::ByteFormat) : Nil
      str = (code == 'o') ? expect_type(val, ObjectPath, 'o').value : expect_type(val, String, 's')
      raise MessageError.new("Object path must start with '/'") if code == 'o' && !str.starts_with?('/')
      raise MessageError.new("String contains embedded NUL byte") if str.to_slice.includes?(0_u8)
      fmt.encode(str.bytesize.to_u32, io)
      io.write(str.to_slice)
      io.write_byte(0_u8)
    end

    private def self.encode_variant(io : IO::Memory, val : Value, fmt : IO::ByteFormat) : Nil
      var = expect_type(val, Variant, 'v')
      SignatureValidator.validate_single(var.signature)
      write_sig_bytes(io, var.signature)
      encode_value(io, var.signature, var.value, fmt)
    end

    private def self.write_sig_bytes(io : IO::Memory, sig : String) : Nil
      SignatureValidator.validate(sig)
      io.write_byte(sig.bytesize.to_u8)
      io.write(sig.to_slice)
      io.write_byte(0_u8)
    end

    private def self.encode_struct(io : IO::Memory, inner_sig : String, val : Value, fmt : IO::ByteFormat) : Nil
      sv = expect_type(val, StructValue, '(')
      field_types = SignatureValidator.split_types(inner_sig)
      unless field_types.size == sv.fields.size
        raise MessageError.new("Struct field count (#{sv.fields.size}) does not match '(#{inner_sig})'")
      end
      field_types.each_with_index { |field_sig, idx| encode_value(io, field_sig, sv.fields[idx], fmt) }
    end

    private def self.encode_array(io : IO::Memory, elem_sig : String, val : Value, fmt : IO::ByteFormat) : Nil
      len_pos = io.pos
      fmt.encode(0_u32, io)
      HeaderCodec.align_write(io, alignment_for(elem_sig))
      data_start = io.pos
      if elem_sig.starts_with?('{')
        encode_dict(io, elem_sig, expect_type(val, Hash(Value, Value), 'a'), fmt)
      else
        expect_type(val, Array(Value), 'a').each { |item| encode_value(io, elem_sig, item, fmt) }
      end
      fmt.encode((io.pos - data_start).to_u32, io.to_slice[len_pos, 4])
    end

    private def self.encode_dict(io : IO::Memory, sig : String, dict : Hash(Value, Value), fmt : IO::ByteFormat) : Nil
      key_sig = sig[1, 1]
      val_sig = sig[2...-1]
      dict.each do |k, v|
        HeaderCodec.align_write(io, 8)
        encode_value(io, key_sig, k, fmt)
        encode_value(io, val_sig, v, fmt)
      end
    end

    private def self.decode_value(io : IO::Memory, sig : String, fmt : IO::ByteFormat) : Value
      align_read(io, alignment_for(sig))
      case sig[0]
      when 'a' then decode_array(io, sig[1..], fmt)
      when '(' then decode_struct(io, sig[1...-1], fmt)
      when 'v' then decode_variant(io, fmt)
      when 's' then HeaderCodec.read_string_field(io, fmt).as(Value)
      when 'o' then ObjectPath.new(HeaderCodec.read_object_path_field(io, fmt)).as(Value)
      when 'g' then Signature.new(HeaderCodec.read_signature_field(io)).as(Value)
      else          decode_primitive(io, sig[0], fmt)
      end
    end

    private def self.decode_primitive(io : IO::Memory, code : Char, fmt : IO::ByteFormat) : Value
      case code
      when 'y' then (io.read_byte || raise IO::EOFError.new).as(Value)
      when 'b' then parse_bool(io.read_bytes(UInt32, fmt)).as(Value)
      when 'n' then io.read_bytes(Int16, fmt).as(Value)
      when 'q' then io.read_bytes(UInt16, fmt).as(Value)
      when 'i' then io.read_bytes(Int32, fmt).as(Value)
      when 'u' then io.read_bytes(UInt32, fmt).as(Value)
      when 'h' then UnixFD.new(io.read_bytes(UInt32, fmt)).as(Value)
      else          decode_wide_primitive(io, code, fmt)
      end
    end

    private def self.decode_wide_primitive(io : IO::Memory, code : Char, fmt : IO::ByteFormat) : Value
      case code
      when 'x' then io.read_bytes(Int64, fmt).as(Value)
      when 't' then io.read_bytes(UInt64, fmt).as(Value)
      when 'd' then io.read_bytes(Float64, fmt).as(Value)
      else          raise SignatureError.new("Unsupported primitive type code: #{code}")
      end
    end

    private def self.decode_variant(io : IO::Memory, fmt : IO::ByteFormat) : Value
      var_sig = HeaderCodec.read_signature_field(io)
      SignatureValidator.validate_single(var_sig)
      Variant.new(var_sig, decode_value(io, var_sig, fmt)).as(Value)
    end

    private def self.decode_struct(io : IO::Memory, inner_sig : String, fmt : IO::ByteFormat) : Value
      field_types = SignatureValidator.split_types(inner_sig)
      StructValue.new(field_types.map { |field_sig| decode_value(io, field_sig, fmt) }).as(Value)
    end

    private def self.decode_array(io : IO::Memory, elem_sig : String, fmt : IO::ByteFormat) : Value
      byte_len = io.read_bytes(UInt32, fmt)
      align_read(io, alignment_for(elem_sig))
      end_pos = io.pos + byte_len.to_i
      raise MessageError.new("Array byte length exceeds message body") if end_pos > io.size
      return decode_dict(io, elem_sig, end_pos, fmt) if elem_sig.starts_with?('{')
      items = Array(Value).new
      while io.pos < end_pos
        items << decode_value(io, elem_sig, fmt)
      end
      items.as(Value)
    end

    private def self.decode_dict(io : IO::Memory, elem_sig : String, end_pos : Int32, fmt : IO::ByteFormat) : Value
      key_sig = elem_sig[1, 1]
      val_sig = elem_sig[2...-1]
      dict = Hash(Value, Value).new
      while io.pos < end_pos
        align_read(io, 8)
        k = decode_value(io, key_sig, fmt)
        dict[k] = decode_value(io, val_sig, fmt)
      end
      dict.as(Value)
    end

    private def self.parse_bool(raw : UInt32) : Bool
      return false if raw == 0_u32
      return true if raw == 1_u32
      raise MessageError.new("Invalid D-Bus boolean value: #{raw}")
    end

    private def self.expect_type(val : Value, type : T.class, code : Char) : T forall T
      return val if val.is_a?(T)
      raise MessageError.new("Type mismatch for '#{code}': expected #{T}, got #{val.class}")
    end

    private def self.align_read(io : IO::Memory, alignment : Int32) : Nil
      pad = (alignment - (io.pos % alignment)) % alignment
      pad.times do
        byte = io.read_byte || raise IO::EOFError.new
        raise MessageError.new("Non-zero alignment padding in body") unless byte == 0_u8
      end
    end
  end
end
