=======================
Security Considerations
=======================

Security is a primary focus for ``crystal-dbus-native``. The library implements strict mitigations against common wire-protocol and IPC vulnerabilities.

Integer and Buffer Safety
=========================

The D-Bus wire protocol relies on length prefixes across fixed headers, header fields, and message bodies. The implementation uses 64-bit unsigned arithmetic and explicit bounds checks before buffer allocation.

Checks are performed before allocations and pointer arithmetic:

.. code-block:: crystal

   # Check total payload size in UInt64 before allocating buffers
   if body_len.to_u64 + fields_len.to_u64 > max_size.to_u64
     raise MessageError.new("Message length exceeds maximum allowed limit")
   end

   # Check cmsghdr bounds before subtraction and pointer dereference
   while offset + hdr_len <= total_len
     cmsg = (base_ptr + offset).as(LibC::Cmsghdr*)
     cmsg_len = cmsg.value.cmsg_len.to_u64
     break if cmsg_len < hdr_len || offset + cmsg_len > total_len
     # Safe subtraction after verifying cmsg_len >= hdr_len
     fd_count = ((cmsg_len - hdr_len) // sizeof(Int32)).to_i
     offset += cmsg_align(cmsg_len).to_u64
   end

Ancillary File Descriptor Hardening
===================================

To prevent file descriptor leaks and exhaustion during ``SCM_RIGHTS`` transfers, ``SecureFDPasser`` enforces:

* ``MSG_CMSG_CLOEXEC`` on all ``recvmsg`` calls so received descriptors cannot leak across ``execve``.
* Immediate extraction and ``LibC.close`` cleanup of all received descriptors whenever ``MSG_CTRUNC`` indicates control buffer truncation or an exception occurs.
* Strict upper limit of ``MAX_FDS = 253`` descriptors per message.

SASL Handshake Protection
=========================

During SASL ``EXTERNAL`` authentication over ``UNIXSocket``, ``SASLAuthenticator`` enforces:

* Bounded line reads capped at ``MAX_LINE_LENGTH = 4096`` bytes to prevent memory exhaustion from unterminated server responses.
* Scoped socket ``read_timeout`` enforcement with guaranteed restoration of the previous timeout inside an ``ensure`` block.
