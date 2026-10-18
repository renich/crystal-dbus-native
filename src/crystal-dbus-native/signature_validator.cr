module Crystal::Dbus::Native
  # Validates D-Bus type signatures against protocol syntax, container nesting, and length rules.
  class SignatureValidator
    # Maximum nesting depth independently permitted for `ARRAY` and `STRUCT`/`DICT_ENTRY` containers.
    MAX_DEPTH = 32

    # Maximum byte length of a D-Bus type signature.
    MAX_LENGTH = 255

    # Valid single-character D-Bus basic type codes permitted as `DICT_ENTRY` keys.
    BASIC_TYPES = "ybnqiuxstodgh"

    # Validates `signature` or raises `SignatureError` if malformed or out of bounds.
    def self.validate(signature : String) : Nil
      split_types(signature)
    end

    # Validates that `signature` contains exactly one complete D-Bus type.
    def self.validate_single(signature : String) : Nil
      types = split_types(signature)
      return if types.size == 1
      raise SignatureError.new("Expected single complete type, got #{types.size} types in '#{signature}'")
    end

    # Validates `signature` and splits it into an array of single complete type signatures.
    def self.split_types(signature : String) : Array(String)
      if signature.bytesize > MAX_LENGTH
        raise SignatureError.new("Signature too long: #{signature.bytesize} > #{MAX_LENGTH}")
      end

      types = Array(String).new
      pos = 0
      bytes = signature.to_slice
      while pos < bytes.size
        next_pos = validate_single_type(bytes, pos, 0, 0, false)
        types << String.new(bytes[pos, next_pos - pos])
        pos = next_pos
      end
      types
    end

    private def self.validate_single_type(
      sig : Bytes,
      pos : Int32,
      array_depth : Int32,
      struct_depth : Int32,
      in_array : Bool,
    ) : Int32
      raise SignatureError.new("Unexpected end of signature") if pos >= sig.size

      if array_depth > MAX_DEPTH || struct_depth > MAX_DEPTH
        raise SignatureError.new("Depth exceeded: array=#{array_depth}, struct=#{struct_depth} > #{MAX_DEPTH}")
      end

      char = sig[pos].chr
      case char
      when .in?(BASIC_TYPES), 'v'
        pos + 1
      when 'a'
        validate_single_type(sig, pos + 1, array_depth + 1, struct_depth, true)
      when '('
        validate_struct(sig, pos + 1, array_depth, struct_depth)
      when '{'
        validate_dict_entry(sig, pos + 1, array_depth, struct_depth, in_array)
      else
        raise SignatureError.new("Invalid type code: #{char}")
      end
    end

    private def self.validate_struct(
      sig : Bytes,
      start_pos : Int32,
      array_depth : Int32,
      struct_depth : Int32,
    ) : Int32
      pos = start_pos
      while pos < sig.size && sig[pos].chr != ')'
        pos = validate_single_type(sig, pos, array_depth, struct_depth + 1, false)
      end
      raise SignatureError.new("Unclosed struct") if pos >= sig.size
      raise SignatureError.new("Empty struct") if pos == start_pos
      pos + 1
    end

    private def self.validate_dict_entry(
      sig : Bytes,
      pos : Int32,
      array_depth : Int32,
      struct_depth : Int32,
      in_array : Bool,
    ) : Int32
      raise SignatureError.new("Dict entry must be inside array") unless in_array

      if pos >= sig.size || !BASIC_TYPES.includes?(sig[pos].chr)
        raise SignatureError.new("Dict key must be a basic type")
      end
      pos += 1

      pos = validate_single_type(sig, pos, array_depth, struct_depth + 1, false)

      if pos >= sig.size || sig[pos].chr != '}'
        raise SignatureError.new("Unclosed dict or too many elements")
      end
      pos + 1
    end
  end
end
