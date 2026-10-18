require "socket"

module Crystal::Dbus::Native
  # Byte-order encoding for D-Bus wire messages.
  enum Endianness : UInt8
    # Little-endian byte order (`'l'`).
    Little = 0x6c_u8
    # Big-endian byte order (`'B'`).
    Big = 0x42_u8
  end

  # D-Bus message types defined by the wire protocol specification.
  enum MessageType : UInt8
    # Method call request message (`METHOD_CALL`).
    MethodCall = 1_u8
    # Method return reply message (`METHOD_RETURN`).
    MethodReturn = 2_u8
    # Error reply message (`ERROR`).
    Error = 3_u8
    # Broadcast or unicast signal emission (`SIGNAL`).
    Signal = 4_u8
  end

  # Represents a framed D-Bus wire protocol message with header fields and payload body.
  class DBusMessage
    # Returns or sets the byte order of the message.
    property endian : Endianness
    # Returns or sets the message type.
    property message_type : MessageType
    # Returns or sets the bitmask of message flags.
    property flags : UInt8
    # Returns or sets the major D-Bus protocol version (`1_u8`).
    property protocol_version : UInt8
    # Returns or sets the non-zero message serial number.
    property serial : UInt32
    # Returns or sets the target or source object path (`HeaderField::PATH`).
    property path : String?
    # Returns or sets the interface name (`HeaderField::INTERFACE`).
    property interface : String?
    # Returns or sets the method or signal member name (`HeaderField::MEMBER`).
    property member : String?
    # Returns or sets the error name (`HeaderField::ERROR_NAME`).
    property error_name : String?
    # Returns or sets the reply serial number (`HeaderField::REPLY_SERIAL`).
    property reply_serial : UInt32?
    # Returns or sets the destination bus name (`HeaderField::DESTINATION`).
    property destination : String?
    # Returns or sets the sender unique bus name (`HeaderField::SENDER`).
    property sender : String?
    # Returns or sets the body type signature (`HeaderField::SIGNATURE`).
    property signature : String?
    # Returns or sets the number of accompanying UNIX file descriptors (`HeaderField::UNIX_FDS`).
    property unix_fds : UInt32?
    # Returns or sets the raw marshaled payload bytes.
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
      serial : UInt32, path : String, interface : String, member : String,
      destination : String? = nil, signature : String? = nil, body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodCall, serial, body: body)
      msg.path, msg.interface, msg.member = path, interface, member
      msg.destination, msg.signature = destination, signature
      msg
    end

    # Constructs a D-Bus `MethodReturn` message.
    def self.method_return(
      serial : UInt32, reply_serial : UInt32,
      destination : String? = nil, signature : String? = nil, body : Bytes = Bytes.empty,
    ) : self
      msg = new(Endianness::Little, MessageType::MethodReturn, serial, body: body)
      msg.reply_serial, msg.destination, msg.signature = reply_serial, destination, signature
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
      parse_from_header(header, io, max_size)
    end

    # Parses the remainder of a D-Bus message from `io` given its 16-byte fixed `header`.
    def self.parse_from_header(header : Bytes, io : IO, max_size : UInt32 = 134_217_728_u32) : self
      endian_sym, msg_type, serial, fields_len, body_len = parse_fixed_header(header, max_size)
      format = (endian_sym == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      fields_data, body_data = read_payload(io, fields_len, body_len)
      msg = new(endian_sym, msg_type, serial, flags: header[2], protocol_version: header[3], body: body_data)
      HeaderCodec.parse_fields(msg, fields_data, format) if fields_len > 0
      msg
    end

    # Serializes this message in D-Bus wire format to `io`.
    def serialize(io : IO) : Nil
      format = (@endian == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      fields_mem = IO::Memory.new
      HeaderCodec.write_fields(self, fields_mem, format)
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

    # Unmarshals the message body into an array of `Value` items using `@signature` and `@endian`.
    def decode_body : Array(Value)
      BodyCodec.decode(@signature || "", @body, @endian)
    end

    # Validates `signature`, sets `@signature`, and marshals `values` into `@body`.
    def encode_body(signature : String, values : Array(Value)) : Nil
      SignatureValidator.validate(signature)
      @signature = signature
      @body = BodyCodec.encode(signature, values, @endian)
    end

    private def self.parse_fixed_header(
      header : Bytes, max_size : UInt32,
    ) : Tuple(Endianness, MessageType, UInt32, UInt32, UInt32)
      endian_sym = Endianness.from_value?(header[0]) ||
                   raise MessageError.new("Invalid endianness byte: #{header[0]}")
      format = (endian_sym == Endianness::Little) ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
      msg_type = MessageType.from_value?(header[1]) ||
                 raise MessageError.new("Unknown message type: #{header[1]}")
      raise MessageError.new("Unsupported D-Bus protocol version: #{header[3]}") unless header[3] == 1_u8

      body_len = format.decode(UInt32, header[4, 4])
      serial = format.decode(UInt32, header[8, 4])
      raise MessageError.new("Invalid message serial: 0") if serial == 0_u32
      fields_len = format.decode(UInt32, header[12, 4])
      if body_len.to_u64 + fields_len.to_u64 > max_size.to_u64
        raise MessageError.new("Message length exceeds maximum allowed limit")
      end
      {endian_sym, msg_type, serial, fields_len, body_len}
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
  end
end
