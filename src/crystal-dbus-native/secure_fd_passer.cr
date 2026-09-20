require "socket"

module Crystal::Dbus::Native
  class SecureFDPasser
    private SIZEOF_SIZE_T    = sizeof(LibC::SizeT)
    private SIZEOF_CMSGHDR   = sizeof(LibC::Cmsghdr)
    private SOL_SOCKET       =          1
    private SCM_RIGHTS       =          1
    private MSG_CTRUNC       =       0x08
    private MSG_CMSG_CLOEXEC = 0x40000000

    private def self.cmsg_align(len : Int) : Int32
      ((len + SIZEOF_SIZE_T - 1) & ~(SIZEOF_SIZE_T - 1)).to_i32
    end

    private def self.cmsg_space(length : Int) : Int32
      cmsg_align(length) + cmsg_align(SIZEOF_CMSGHDR)
    end

    private def self.cmsg_len(length : Int) : Int32
      cmsg_align(SIZEOF_CMSGHDR) + length.to_i32
    end

    def self.send_fds(socket : UNIXSocket, data : Bytes, fds : Array(Int32)) : Nil
      if fds.size > 253
        raise DBusError.new("Too many FDs: maximum is 253, got #{fds.size}")
      end

      if fds.empty?
        socket.write(data)
        socket.flush
        return
      end

      iov = LibC::Iovec.new
      iov.iov_base = data.to_unsafe.as(Void*)
      iov.iov_len = data.size

      msg = LibC::Msghdr.new
      msg.msg_name = Pointer(Void).null
      msg.msg_namelen = 0
      msg.msg_iov = pointerof(iov)
      msg.msg_iovlen = 1

      fd_byte_size = fds.size * sizeof(Int32)
      control_buf_size = cmsg_space(fd_byte_size)
      control_buf = Bytes.new(control_buf_size)

      msg.msg_control = control_buf.to_unsafe.as(Void*)
      msg.msg_controllen = control_buf_size

      cmsg = control_buf.to_unsafe.as(LibC::Cmsghdr*)
      cmsg.value.cmsg_len = cmsg_len(fd_byte_size).to_u64
      cmsg.value.cmsg_level = SOL_SOCKET
      cmsg.value.cmsg_type = SCM_RIGHTS

      fd_ptr = (control_buf.to_unsafe.as(UInt8*) + cmsg_align(SIZEOF_CMSGHDR)).as(Int32*)
      fds.each_with_index do |file_desc, i|
        fd_ptr[i] = file_desc
      end

      loop do
        res = LibC.sendmsg(socket.fd, pointerof(msg), 0)
        if res >= 0
          return
        elsif Errno.value == Errno::EAGAIN || Errno.value == Errno::EWOULDBLOCK
          Crystal::EventLoop.current.wait_writable(socket)
        else
          raise DBusError.new("sendmsg failed: #{Errno.value}")
        end
      end
    end

    def self.recv_fds(socket : UNIXSocket, buffer : Bytes, max_fds = 253) : Tuple(Int32, Array(Int32))
      if max_fds > 253
        raise DBusError.new("max_fds too large: maximum is 253, got #{max_fds}")
      end

      iov = LibC::Iovec.new
      iov.iov_base = buffer.to_unsafe.as(Void*)
      iov.iov_len = buffer.size

      msg = LibC::Msghdr.new
      msg.msg_name = Pointer(Void).null
      msg.msg_namelen = 0
      msg.msg_iov = pointerof(iov)
      msg.msg_iovlen = 1

      control_buf_size = cmsg_space(max_fds * sizeof(Int32))
      control_buf = Bytes.new(control_buf_size)

      msg.msg_control = control_buf.to_unsafe.as(Void*)
      msg.msg_controllen = control_buf_size

      res = LibC::SSizeT.new(-1)
      loop do
        res = LibC.recvmsg(socket.fd, pointerof(msg), MSG_CMSG_CLOEXEC)
        if res >= 0
          break
        elsif Errno.value == Errno::EAGAIN || Errno.value == Errno::EWOULDBLOCK
          Crystal::EventLoop.current.wait_readable(socket)
        else
          raise DBusError.new("recvmsg failed: #{Errno.value}")
        end
      end

      if (msg.msg_flags & MSG_CTRUNC) != 0
        raise DBusError.new("Ancillary control data was truncated")
      end

      received_fds = [] of Int32
      begin
        extract_received_fds(msg, received_fds)
        {res.to_i, received_fds}
      rescue ex
        received_fds.each { |descriptor| LibC.close(descriptor) }
        raise ex
      end
    end

    private def self.extract_received_fds(msg : LibC::Msghdr, received_fds : Array(Int32)) : Nil
      return unless msg.msg_controllen > 0

      cmsg = msg.msg_control.as(LibC::Cmsghdr*)
      hdr_len = cmsg_align(SIZEOF_CMSGHDR)

      if cmsg.value.cmsg_level == SOL_SOCKET && cmsg.value.cmsg_type == SCM_RIGHTS
        if cmsg.value.cmsg_len >= hdr_len
          fd_bytes = cmsg.value.cmsg_len - hdr_len
          fd_count = (fd_bytes // sizeof(Int32)).to_i
          fd_ptr = (msg.msg_control.as(UInt8*) + hdr_len).as(Int32*)
          fd_count.times do |i|
            received_fds << fd_ptr[i]
          end
        end
      end
    end
  end
end
