require "socket"

module Crystal::Dbus::Native
  # Encapsulates UNIX domain socket file descriptor passing via `SCM_RIGHTS` ancillary control messages.
  class SecureFDPasser
    # Maximum number of file descriptors permitted in a single `SCM_RIGHTS` control message on Linux.
    MAX_FDS = 253

    private SIZEOF_SIZE_T    = sizeof(LibC::SizeT)
    private SIZEOF_CMSGHDR   = sizeof(LibC::Cmsghdr)
    private SOL_SOCKET       =          1
    private SCM_RIGHTS       =          1
    private MSG_CTRUNC       =       0x08
    private MSG_CMSG_CLOEXEC = 0x40000000

    # Sends `data` bytes and an array of open file descriptors `fds` over `socket` using `SCM_RIGHTS`.
    def self.send_fds(socket : UNIXSocket, data : Bytes, fds : Array(Int32)) : Nil
      raise DBusError.new("Too many FDs: maximum is #{MAX_FDS}, got #{fds.size}") if fds.size > MAX_FDS
      if fds.empty?
        socket.write(data)
        socket.flush
        return
      end

      iov = LibC::Iovec.new(iov_base: data.to_unsafe.as(Void*), iov_len: data.size)
      fd_byte_size = fds.size * sizeof(Int32)
      control_buf = Bytes.new(cmsg_space(fd_byte_size))
      msg = build_msghdr(pointerof(iov), control_buf)
      cmsg = control_buf.to_unsafe.as(LibC::Cmsghdr*)
      cmsg.value.cmsg_len = cmsg_len(fd_byte_size).to_u64
      cmsg.value.cmsg_level = SOL_SOCKET
      cmsg.value.cmsg_type = SCM_RIGHTS
      fd_ptr = (control_buf.to_unsafe.as(UInt8*) + cmsg_align(SIZEOF_CMSGHDR)).as(Int32*)
      fds.each_with_index { |file_desc, i| fd_ptr[i] = file_desc }
      perform_sendmsg(socket, pointerof(msg))
    end

    # Receives bytes into `buffer` and up to `max_fds` file descriptors via `SCM_RIGHTS` with `MSG_CMSG_CLOEXEC`.
    def self.recv_fds(socket : UNIXSocket, buffer : Bytes, max_fds : Int32 = MAX_FDS) : Tuple(Int32, Array(Int32))
      if max_fds < 0 || max_fds > MAX_FDS
        raise DBusError.new("max_fds too large: maximum is #{MAX_FDS}, got #{max_fds}")
      end

      iov = LibC::Iovec.new
      iov.iov_base = buffer.to_unsafe.as(Void*)
      iov.iov_len = buffer.size

      control_buf = Bytes.new(cmsg_space(max_fds * sizeof(Int32)))
      msg = build_msghdr(pointerof(iov), control_buf)
      bytes_read = perform_recvmsg(socket, pointerof(msg))

      received_fds = Array(Int32).new
      begin
        extract_received_fds(msg, received_fds)
        if (msg.msg_flags & MSG_CTRUNC) != 0
          raise DBusError.new("Ancillary control data was truncated")
        end
        {bytes_read, received_fds}
      rescue ex
        received_fds.each { |descriptor| LibC.close(descriptor) }
        raise ex
      end
    end

    private def self.cmsg_align(len : Int) : Int32
      ((len + SIZEOF_SIZE_T - 1) & ~(SIZEOF_SIZE_T - 1)).to_i32
    end

    private def self.cmsg_space(length : Int) : Int32
      cmsg_align(length) + cmsg_align(SIZEOF_CMSGHDR)
    end

    private def self.cmsg_len(length : Int) : Int32
      cmsg_align(SIZEOF_CMSGHDR) + length.to_i32
    end

    private def self.build_msghdr(iov : LibC::Iovec*, control_buf : Bytes) : LibC::Msghdr
      msg = LibC::Msghdr.new
      msg.msg_name = Pointer(Void).null
      msg.msg_namelen = 0
      msg.msg_iov = iov
      msg.msg_iovlen = 1
      msg.msg_control = control_buf.to_unsafe.as(Void*)
      msg.msg_controllen = control_buf.size
      msg
    end

    private def self.perform_sendmsg(socket : UNIXSocket, msg : LibC::Msghdr*) : Nil
      loop do
        res = LibC.sendmsg(socket.fd, msg, 0)
        return if res >= 0

        case Errno.value
        when Errno::EINTR
          next
        when Errno::EAGAIN, Errno::EWOULDBLOCK
          Crystal::EventLoop.current.wait_writable(socket)
        else
          raise DBusError.new("sendmsg failed: #{Errno.value}")
        end
      end
    end

    private def self.perform_recvmsg(socket : UNIXSocket, msg : LibC::Msghdr*) : Int32
      loop do
        res = LibC.recvmsg(socket.fd, msg, MSG_CMSG_CLOEXEC)
        return res.to_i if res >= 0

        case Errno.value
        when Errno::EINTR
          next
        when Errno::EAGAIN, Errno::EWOULDBLOCK
          Crystal::EventLoop.current.wait_readable(socket)
        else
          raise DBusError.new("recvmsg failed: #{Errno.value}")
        end
      end
    end

    private def self.extract_received_fds(msg : LibC::Msghdr, received_fds : Array(Int32)) : Nil
      total_len = msg.msg_controllen.to_u64
      return if total_len == 0 || msg.msg_control.null?

      base_ptr = msg.msg_control.as(UInt8*)
      hdr_len = cmsg_align(SIZEOF_CMSGHDR).to_u64
      offset = 0_u64

      while offset + hdr_len <= total_len
        cmsg = (base_ptr + offset).as(LibC::Cmsghdr*)
        cmsg_len = cmsg.value.cmsg_len.to_u64
        break if cmsg_len < hdr_len || offset + cmsg_len > total_len

        if cmsg.value.cmsg_level == SOL_SOCKET && cmsg.value.cmsg_type == SCM_RIGHTS
          fd_count = ((cmsg_len - hdr_len) // sizeof(Int32)).to_i
          fd_ptr = (base_ptr + offset + hdr_len).as(Int32*)
          fd_count.times { |i| received_fds << fd_ptr[i] }
        end

        step = cmsg_align(cmsg_len).to_u64
        break if step == 0
        offset += step
      end
    end
  end
end
