module Crystal::Dbus::Native
  # Represents a validated D-Bus `OBJECT_PATH` (`o`) value.
  struct ObjectPath
    # Returns the string representation of the object path.
    getter value : String

    # Creates a new `ObjectPath` wrapping `value`.
    def initialize(@value : String) : Nil
    end
  end

  # Represents a validated D-Bus `SIGNATURE` (`g`) value.
  struct Signature
    # Returns the string representation of the type signature.
    getter value : String

    # Creates a new `Signature` wrapping `value`.
    def initialize(@value : String) : Nil
    end
  end

  # Represents a D-Bus `UNIX_FD` (`h`) 0-based file descriptor index.
  struct UnixFD
    # Returns the 0-based index into the ancillary file descriptor array.
    getter index : UInt32

    # Creates a new `UnixFD` wrapping `index`.
    def initialize(@index : UInt32) : Nil
    end
  end

  # Represents a D-Bus `STRUCT` (`(...)`) container value.
  struct StructValue
    # Returns the ordered field values of the struct.
    getter fields : Array(Value)

    # Creates a new `StructValue` wrapping `fields`.
    def initialize(@fields : Array(Value)) : Nil
    end
  end

  # Represents a dynamically typed D-Bus `VARIANT` (`v`) container value.
  struct Variant
    # Returns the single complete D-Bus type signature of the boxed value.
    getter signature : String

    @boxed : Array(Value)

    # Creates a new `Variant` with `signature` and boxed `value`.
    def initialize(@signature : String, value : Value) : Nil
      @boxed = [value] of Value
    end

    # Returns the unwrapped payload `Value`.
    def value : Value
      @boxed[0]
    end
  end

  # Union of all supported D-Bus wire protocol payload values.
  alias Value = UInt8 | Bool | Int16 | UInt16 | Int32 | UInt32 | Int64 | UInt64 |
                Float64 | String | ObjectPath | Signature | UnixFD | Variant |
                StructValue | Array(Value) | Hash(Value, Value)
end
