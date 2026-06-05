class UNIXSocket < Socket
  def self.new(family : Socket::Family, type : Socket::Type, protocol : Socket::Protocol = Socket::Protocol::IP)
    super(family, type, protocol)
  end
end

require "socket"

module Crystal::Dbus::Native
  class SecureFDPasser
    private SIZEOF_SIZE_T  = sizeof(LibC::SizeT)
    private SIZEOF_CMSGHDR = sizeof(LibC::Cmsghdr)

    private def self.cmsg_align(len)
      (len + SIZEOF_SIZE_T - 1) & ~(SIZEOF_SIZE_T - 1)
    end

    private def self.cmsg_space(length)
      cmsg_align(length) + cmsg_align(SIZEOF_CMSGHDR)
    end

    private def self.cmsg_len(length)
      cmsg_align(SIZEOF_CMSGHDR) + length
    end

    def self.send_fds(socket : UNIXSocket, data : Bytes, fds : Array(Int32))
      if fds.size > 253
        raise DBusError.new("Too many FDs")
      end

      if fds.empty?
        socket.write(data)
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
      cmsg.value.cmsg_len = cmsg_len(fd_byte_size)
      cmsg.value.cmsg_level = 1
      cmsg.value.cmsg_type = 1

      fd_ptr = (control_buf.to_unsafe.as(UInt8*) + cmsg_align(SIZEOF_CMSGHDR)).as(Int32*)
      fds.each_with_index do |file_desc, i|
        fd_ptr[i] = file_desc
      end

      res = LibC.sendmsg(socket.fd, pointerof(msg), 0)
      if res < 0
        raise DBusError.new("sendmsg failed: #{Errno.value}")
      end
    end

    def self.recv_fds(socket : UNIXSocket, buffer : Bytes, max_fds = 253)
      if max_fds > 253
        raise DBusError.new("max_fds too large")
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

      res = LibC.recvmsg(socket.fd, pointerof(msg), 0)
      if res < 0
        raise DBusError.new("recvmsg failed: #{Errno.value}")
      end

      received_fds = [] of Int32

      if msg.msg_controllen > 0
        cmsg = msg.msg_control.as(LibC::Cmsghdr*)
        if cmsg.value.cmsg_level == 1 && cmsg.value.cmsg_type == 1
          fd_count = (cmsg.value.cmsg_len - cmsg_align(SIZEOF_CMSGHDR)) // sizeof(Int32)
          fd_ptr = (msg.msg_control.as(UInt8*) + cmsg_align(SIZEOF_CMSGHDR)).as(Int32*)
          fd_count.times do |i|
            received_fds << fd_ptr[i]
          end
        end
      end

      {res.to_i, received_fds, nil}
    end
  end
end
