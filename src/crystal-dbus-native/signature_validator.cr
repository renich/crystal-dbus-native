module Crystal::Dbus::Native
  class SignatureValidator
    MAX_DEPTH  =  32
    MAX_LENGTH = 255

    BASIC_TYPES = "ybnqiuxstodgh"

    def self.validate(signature : String) : Nil
      if signature.bytesize > MAX_LENGTH
        raise SignatureError.new("Signature too long: #{signature.bytesize} > #{MAX_LENGTH}")
      end

      pos = 0
      bytes = signature.to_slice
      while pos < bytes.size
        pos = validate_single_type(bytes, pos, 0, false)
      end
    end

    private def self.validate_single_type(sig : Bytes, pos : Int32, depth : Int32, in_array : Bool) : Int32
      if pos >= sig.size
        raise SignatureError.new("Unexpected end of signature")
      end
      if depth > MAX_DEPTH
        raise SignatureError.new("Depth exceeded: #{depth} > #{MAX_DEPTH}")
      end

      char = sig[pos].chr

      if BASIC_TYPES.includes?(char)
        pos + 1
      elsif char == 'v'
        pos + 1
      elsif char == 'a'
        validate_single_type(sig, pos + 1, depth + 1, true)
      elsif char == '('
        validate_struct(sig, pos + 1, depth)
      elsif char == '{'
        validate_dict_entry(sig, pos + 1, depth, in_array)
      else
        raise SignatureError.new("Invalid type code: #{char}")
      end
    end

    private def self.validate_struct(sig : Bytes, start_pos : Int32, depth : Int32) : Int32
      pos = start_pos
      while pos < sig.size && sig[pos].chr != ')'
        pos = validate_single_type(sig, pos, depth + 1, false)
      end
      if pos >= sig.size
        raise SignatureError.new("Unclosed struct")
      end
      if pos == start_pos
        raise SignatureError.new("Empty struct")
      end
      pos + 1
    end

    private def self.validate_dict_entry(sig : Bytes, pos : Int32, depth : Int32, in_array : Bool) : Int32
      unless in_array
        raise SignatureError.new("Dict entry must be inside array")
      end

      if pos >= sig.size || !BASIC_TYPES.includes?(sig[pos].chr)
        raise SignatureError.new("Dict key must be a basic type")
      end
      pos += 1

      pos = validate_single_type(sig, pos, depth + 1, false)

      if pos >= sig.size || sig[pos].chr != '}'
        raise SignatureError.new("Unclosed dict or too many elements")
      end
      pos + 1
    end
  end
end
