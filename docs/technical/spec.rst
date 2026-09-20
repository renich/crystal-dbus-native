Crystal D-Bus Native Technical Specification
============================================

Version: 0.3.0-fixed
Status: Draft - All BLOCKER issues addressed
Target: Native D-Bus implementation with SCM_RIGHTS security

Overview
--------

This document specifies a native Crystal implementation of the D-Bus message
bus protocol. This revision addresses all adversarial review BLOCKER issues.

SCM_RIGHTS Security (REVISED)
-----------------------------

Integer Underflow Protection (BLOCKER #1 Fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** `cmsg_len - sizeof(CMsgHdr)` could underflow if `cmsg_len` is small.

**Solution:** Validate bounds BEFORE subtraction.

```crystal
class FDPasser
  MAX_FD_COUNT = 253  # Linux SCM_MAX_FD limit
  CMSG_HDR_SIZE = sizeof(LibC::CMsgHdr)
  
  def self.recv_fds(
    socket : Socket,
    buffer : Bytes,
    max_fds : Int32 = MAX_FD_COUNT
  ) : Tuple(Int32, Array(Int32))
    raise ArgumentError.new("max_fds too large") if max_fds > MAX_FD_COUNT
    
    # ... setup msg header ...
    
    result = LibC.recvmsg(socket.fd, pointerof(msg), 0)
    
    if result < 0
      errno = Errno.new("recvmsg")
      raise FDPassError.new("recvmsg failed: #{errno}")
    end
    
    if result == 0
      return {0, [] of Int32}  # EOF
    end
    
    received_fds = [] of Int32
    
    if msg.msg_controllen > 0
      cmsghdr = msg.msg_control.as(LibC::CMsgHdr*)
      
      # BLOCKER #1 Fix: Validate cmsg_len before subtraction
      cmsg_len = cmsghdr.value.cmsg_len
      
      if cmsg_len < CMSG_HDR_SIZE
        raise FDPassError.new("Invalid cmsg_len: #{cmsg_len} < #{CMSG_HDR_SIZE}")
      end
      
      # Safe subtraction after validation
      fd_data_len = cmsg_len - CMSG_HDR_SIZE
      fd_count = fd_data_len // sizeof(Int32)
      
      # Validate fd_count is reasonable
      if fd_count < 0 || fd_count > MAX_FD_COUNT
        raise FDPassError.new("Invalid FD count: #{fd_count}")
      end
      
      if cmsghdr.value.cmsg_level == LibC::SOL_SOCKET && 
         cmsghdr.value.cmsg_type == LibC::SCM_RIGHTS
        
        fd_array = (msg.msg_control.as(UInt8*) + CMSG_HDR_SIZE).as(Int32*)
        
        fd_count.times do |i|
          fd = fd_array[i]
          
          # BLOCKER #4 Fix: Set FD_CLOEXEC on received FDs
          set_cloexec(fd)
          
          received_fds << fd
        end
      end
    end
    
    {result.to_i32, received_fds}
  end
  
  # BLOCKER #4 Fix: Set FD_CLOEXEC to prevent leaking to child processes
  private def self.set_cloexec(fd : Int32)
    flags = LibC.fcntl(fd, LibC::F_GETFD, 0)
    if flags < 0
      raise FDPassError.new("fcntl(F_GETFD) failed")
    end
    
    result = LibC.fcntl(fd, LibC::F_SETFD, flags | LibC::FD_CLOEXEC)
    if result < 0
      raise FDPassError.new("fcntl(F_SETFD) failed")
    end
  end
end

# FFI constants for fcntl
lib LibC
  F_GETFD = 1
  F_SETFD = 2
  FD_CLOEXEC = 1
  
  fun fcntl(fd : Int, cmd : Int, ...) : Int
end
```

Message Size Validation (BLOCKER #2 Fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** `header_size + body_length` could overflow.

**Solution:** Check before addition using saturating arithmetic or comparison.

```crystal
class Message
  PROTOCOL_VERSION = 1
  MAX_MESSAGE_SIZE = 134217728  # 128MB
  HEADER_SIZE = 12
  
  def self.parse(socket : Socket, max_size : Int32 = MAX_MESSAGE_SIZE) : Message
    # Read fixed header (12 bytes minimum)
    header = Bytes.new(HEADER_SIZE)
    read_exact(socket, header, max_timeout: 30.seconds)  # BLOCKER #6 Fix
    
    # Parse endianness
    endian = header[0] == 'l'.ord ? Endian::Little : Endian::Big
    
    # Parse body length
    body_length = endian == Endian::Little ? 
      IO::ByteFormat::LittleEndian.decode(UInt32, header[4..7]) :
      IO::ByteFormat::BigEndian.decode(UInt32, header[4..7])
    
    # BLOCKER #2 Fix: Validate body_length BEFORE addition
    # Use saturating check: if body_length > max_size - HEADER_SIZE, it's too big
    if body_length > max_size - HEADER_SIZE
      raise MessageTooLargeError.new("Body length #{body_length} exceeds maximum")
    end
    
    # Safe addition: we've verified it won't overflow
    total_size = HEADER_SIZE + body_length.to_i64  # Use Int64 to be safe
    
    if total_size > max_size
      raise MessageTooLargeError.new("Total message size #{total_size} exceeds maximum")
    end
    
    # ... continue parsing ...
  end
  
  # BLOCKER #6 Fix: read_exact with timeout
  private def self.read_exact(socket : Socket, buffer : Bytes, max_timeout : Time::Span)
    socket.read_timeout = max_timeout
    
    total_read = 0
    while total_read < buffer.size
      bytes_read = socket.read(buffer[total_read..-1])
      raise ProtocolError.new("Socket closed while reading") if bytes_read == 0
      total_read += bytes_read
    end
  end
end
```

SASL Line Length Limit (BLOCKER #3 Fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** `read_line` could grow unbounded.

**Solution:** Enforce maximum line length.

```crystal
class SASLAuthenticator
  MAX_SASL_LINE_LENGTH = 4096  # BLOCKER #3 Fix
  
  def authenticate(socket : Socket, claimed_uid : UInt32, timeout : Time::Span = 5.seconds) : String
    socket.read_timeout = timeout
    socket.write_timeout = timeout
    
    # Send NUL byte
    socket.write_bytes(0u8)
    
    # Send AUTH EXTERNAL
    uid_hex = claimed_uid.to_s(16).upcase.rjust(8, '0')
    socket << "AUTH EXTERNAL #{uid_hex}\r\n"
    socket.flush
    
    # Read response with length limit
    response = read_line_limited(socket, MAX_SASL_LINE_LENGTH, timeout)
    
    unless response.starts_with?("OK ")
      raise SASLError.new("Authentication failed")
    end
    
    # ... continue ...
  end
  
  # BLOCKER #3 Fix: Read line with maximum length
  private def read_line_limited(socket : Socket, max_length : Int32, timeout : Time::Span) : String
    line = IO::Memory.new
    deadline = Time.monotonic + timeout
    
    while Time.monotonic < deadline
      begin
        byte = socket.read_byte
        break unless byte
        
        # BLOCKER #3 Fix: Check length limit
        if line.size >= max_length
          raise SASLError.new("SASL line exceeds maximum length #{max_length}")
        end
        
        line.write_byte(byte)
        
        # Check for CRLF
        if line.size >= 2
          bytes = line.to_slice
          if bytes[-2] == 0x0d && bytes[-1] == 0x0a
            return String.new(bytes[0..-3])
          end
        end
      rescue IO::TimeoutError
        raise SASLError.new("SASL read timeout")
      end
    end
    
    raise SASLError.new("SASL incomplete response")
  end
end
```

Connection Close Synchronization (BLOCKER #5 Fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Race between reader Fiber and close().

**Solution:** Use Channel for proper shutdown coordination.

```crystal
class Connection
  MAX_PENDING_CALLS = 1024
  
  @transport : Transport
  @serial : UInt32 = 0
  @pending_calls : Hash(UInt32, Channel(Message)) = {} of UInt32 => Channel(Message)
  @signal_handlers : Hash(String, Array(SignalHandler)) = {} of String => Array(SignalHandler)
  
  # BLOCKER #5 Fix: Use Atomic and Channel for proper shutdown
  @running : Atomic(Bool) = Atomic.new(false)
  @shutdown_channel : Channel(Nil) = Channel(Nil).new(1)
  @reader_mutex : Mutex = Mutex.new
  
  def initialize(@transport : Transport)
  end
  
  # Start reader Fiber
  def run : Nil
    @running.set(true)
    
    spawn do
      reader_loop
    end
  end
  
  private def reader_loop
    while @running.get
      begin
        msg = read_message
        handle_message(msg)
      rescue ex
        # Log error, continue unless shutdown requested
        break unless @running.get
      end
    end
    
    # Signal shutdown complete
    @shutdown_channel.send(nil)
  end
  
  # BLOCKER #5 Fix: Proper synchronized close
  def close(timeout : Time::Span = 5.seconds) : Nil
    # Signal reader to stop
    @running.set(false)
    
    # Wait for reader to finish with timeout
    select
    when @shutdown_channel.receive
      # Reader stopped cleanly
    when timeout(timeout)
      # Reader didn't stop in time - force close anyway
    end
    
    # Now safe to clean up pending calls
    pending_mutex.synchronize do
      @pending_calls.each_value do |channel|
        channel.close
      end
      @pending_calls.clear
    end
    
    @transport.close
  end
end
```

Signature Depth Validation (BLOCKER #7 Fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Recursive signature parsing could stack overflow.

**Solution:** Pre-validate signature depth iteratively.

```crystal
class SignatureValidator
  MAX_SIGNATURE_DEPTH = 32
  MAX_SIGNATURE_LENGTH = 255
  
  # BLOCKER #7 Fix: Pre-validate signature depth before parsing
  def self.validate_depth(signature : String) : Int32
    depth = 0
    max_depth = 0
    
    signature.each_char do |char|
      case char
      when '(', 'a', '{'
        depth += 1
        max_depth = Math.max(max_depth, depth)
        if depth > MAX_SIGNATURE_DEPTH
          raise SignatureError.new("Signature depth #{depth} exceeds maximum #{MAX_SIGNATURE_DEPTH}")
        end
      when ')', '}'
        depth -= 1
        if depth < 0
          raise SignatureError.new("Unbalanced signature: too many closing delimiters")
        end
      end
    end
    
    if depth != 0
      raise SignatureError.new("Unbalanced signature: unclosed delimiters")
    end
    
    max_depth
  end
  
  # Validate before marshaling
  def self.validate(signature : String)
    if signature.size > MAX_SIGNATURE_LENGTH
      raise SignatureError.new("Signature length #{signature.size} exceeds maximum #{MAX_SIGNATURE_LENGTH}")
    end
    
    validate_depth(signature)
  end
end

class Marshaler
  MAX_DEPTH = 32
  
  @io : IO
  @endian : Endian
  @fds : Array(Int32) = [] of Int32
  @depth : Int32 = 0
  
  def marshal(value : DBusValue, signature : String) : Nil
    # BLOCKER #7 Fix: Validate signature before recursive parsing
    SignatureValidator.validate(signature) if @depth == 0
    
    @depth += 1
    raise DepthExceededError.new("Maximum marshaling depth exceeded") if @depth > MAX_DEPTH
    
    begin
      case signature[0]
      when 'y' then marshal_byte(value.as(UInt8))
      when 'b' then marshal_boolean(value.as(Bool))
      when 'n' then marshal_int16(value.as(Int16))
      when 'q' then marshal_uint16(value.as(UInt16))
      when 'i' then marshal_int32(value.as(Int32))
      when 'u' then marshal_uint32(value.as(UInt32))
      when 'x' then marshal_int64(value.as(Int64))
      when 't' then marshal_uint64(value.as(UInt64))
      when 'd' then marshal_double(value.as(Float64))
      when 's' then marshal_string(value.as(String))
      when 'o' then marshal_object_path(value.as(ObjectPath))
      when 'g' then marshal_signature(value.as(Signature))
      when 'a' then marshal_array(value.as(Array), signature[1..-1])
      when '(' then marshal_struct(value.as(Tuple), signature)
      when 'v' then marshal_variant(value.as(Variant))
      when 'h' then marshal_unix_fd(value.as(UnixFD))
      else
        raise MarshalError.new("Unknown type code: #{signature[0]}")
      end
    ensure
      @depth -= 1
    end
  end
end
```

Error Handling
--------------

```crystal
class DBusError < Exception; end
class SASLError < DBusError; end
class MarshalError < DBusError; end
class UnmarshalError < DBusError; end
class ProtocolError < DBusError; end
class TimeoutError < DBusError; end
class DepthExceededError < DBusError; end
class MessageTooLargeError < DBusError; end
class SignatureError < DBusError; end
class FDPassError < DBusError; end
```

Security Fixes Summary
----------------------

| Blocker | Issue | Fix |
|---------|-------|-----|
| #1 | Integer underflow in FD count | Validate cmsg_len >= sizeof(CMsgHdr) before subtraction |
| #2 | Integer overflow in message size | Check `body_length > max_size - header_size` before addition |
| #3 | Unbounded SASL line growth | Enforce MAX_SASL_LINE_LENGTH (4096 bytes) |
| #4 | FDs leak to child processes | Set FD_CLOEXEC with fcntl on all received FDs |
| #5 | Race in connection close | Use Channel for shutdown coordination with timeout |
| #6 | read_exact hangs forever | Add timeout parameter to all socket reads |
| #7 | Signature parsing stack overflow | Pre-validate signature depth iteratively before parsing |

Testing Requirements
--------------------

1. **Integer Safety**: Fuzz with max/min values
2. **FD Passing**: Verify CLOEXEC set, test overflow scenarios
3. **SASL**: Test max line length, timeout handling
4. **Connection**: Test rapid open/close cycles
5. **Signatures**: Test deeply nested signatures rejected
6. **Timeouts**: Test all timeout paths

References
----------

- D-Bus Specification 1.0
- SCM_RIGHTS man pages
- sendmsg/recvmsg documentation
- fcntl(FD_CLOEXEC) documentation
