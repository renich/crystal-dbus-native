module Crystal::Dbus::Native
  class SignatureValidator
    MAX_DEPTH  =  32
    MAX_LENGTH = 255

    BASIC_TYPES = "ybnqiuxstodgvh"

    def self.validate(signature : String)
      if signature.bytesize > MAX_LENGTH
        raise SignatureError.new("too long")
      end

      pos = 0
      while pos < signature.bytesize
        pos = validate_single_type(signature, pos, 0, false)
      end
    end

    private def self.validate_single_type(sig : String, pos : Int32, depth : Int32, in_array : Bool) : Int32
      if pos >= sig.bytesize
        raise SignatureError.new("Unexpected end of signature")
      end
      if depth > MAX_DEPTH
        raise SignatureError.new("Depth exceeded")
      end

      char = sig[pos]

      if BASIC_TYPES.includes?(char)
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

    private def self.validate_struct(sig : String, start_pos : Int32, depth : Int32) : Int32
      pos = start_pos
      while pos < sig.bytesize && sig[pos] != ')'
        pos = validate_single_type(sig, pos, depth + 1, false)
      end
      if pos >= sig.bytesize
        raise SignatureError.new("Unclosed struct")
      end
      if pos == start_pos
        raise SignatureError.new("Empty struct")
      end
      pos + 1
    end

    private def self.validate_dict_entry(sig : String, pos : Int32, depth : Int32, in_array : Bool) : Int32
      unless in_array
        raise SignatureError.new("Dict entry must be inside array")
      end

      if pos >= sig.bytesize || !BASIC_TYPES.includes?(sig[pos])
        raise SignatureError.new("Dict key must be basic type")
      end
      pos += 1

      pos = validate_single_type(sig, pos, depth + 1, false)

      if pos >= sig.bytesize || sig[pos] != '}'
        raise SignatureError.new("Unclosed dict or too many elements")
      end
      pos + 1
    end
  end
end
