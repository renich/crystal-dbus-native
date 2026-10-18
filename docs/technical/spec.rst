============================================
Crystal D-Bus Native Technical Specification
============================================

:Version: 0.1.2
:Status: Active
:Target: Native D-Bus wire protocol implementation with SCM_RIGHTS security

Overview
========

This document specifies the native Crystal implementation of the D-Bus message bus protocol in ``Crystal::Dbus::Native``. All wire framing, SASL authentication, signature validation, and UNIX socket file descriptor passing operations are implemented without C library bindings to ``libdbus``.

Ancillary File Descriptor Security
==================================

``SecureFDPasser`` encapsulates ``sendmsg`` and ``recvmsg`` with ``SCM_RIGHTS`` ancillary data over ``UNIXSocket``.

* Enforces ``MAX_FDS = 253`` on both transmission and reception.
* Passes ``MSG_CMSG_CLOEXEC`` to ``LibC.recvmsg`` so received descriptors are atomically marked close-on-exec.
* Retries ``sendmsg`` and ``recvmsg`` on ``Errno::EINTR`` and yields to ``Crystal::EventLoop.current`` on ``Errno::EAGAIN``/``Errno::EWOULDBLOCK``.
* Extracts received descriptors across all ``LibC::Cmsghdr`` headers with ``UInt64`` bounds checks before inspecting ``MSG_CTRUNC``, ensuring every descriptor is closed via ``LibC.close`` if truncation or an error occurs.

.. code-block:: crystal

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

Message Framing and Header Validation
=====================================

``DBusMessage`` implements D-Bus wire protocol version 1 framing:

* Uses a stack-allocated 16-byte buffer (``uninitialized StaticArray(UInt8, 16)``) for the fixed header.
* Validates the endianness byte strictly against ``Endianness::Little`` (``0x6c``) and ``Endianness::Big`` (``0x42``).
* Rejects message serial ``0_u32`` and unsupported protocol versions.
* Verifies ``body_len.to_u64 + fields_len.to_u64 <= max_size.to_u64`` (default 128 MiB) prior to heap allocation.
* Validates header field codes (``PATH`` through ``UNIX_FDS``), variant type signatures (``o``, ``s``, ``g``, ``u``), NUL terminators, UTF-8 encoding, and zeroed 8-byte alignment padding.
* Computes ``body_length`` dynamically from ``@body.size.to_u32``.

.. code-block:: crystal

   header_buf = uninitialized StaticArray(UInt8, 16)
   header = header_buf.to_slice
   io.read_fully(header)

   endian_sym = Endianness.from_value?(header[0]) ||
                raise MessageError.new("Invalid endianness byte: #{header[0]}")

SASL Authentication Handshake
=============================

``SASLAuthenticator`` implements client-side ``AUTH EXTERNAL`` authentication and optional ``NEGOTIATE_UNIX_FD`` negotiation:

* Sends the initial ``0x00`` credential byte followed by ``AUTH EXTERNAL <hex-ascii-uid>\r\n``.
* Enforces ``MAX_LINE_LENGTH = 4096`` on server responses via ``client.gets(limit: MAX_LINE_LENGTH, chomp: true)`` and raises ``AuthError`` if the line exceeds the maximum length or times out.
* Restores the socket's original ``read_timeout`` in an ``ensure`` block.

Connection Lifecycle and Serial Allocation
==========================================

``DBusConnection`` manages the ``UNIXSocket`` lifecycle, SASL authentication, ``org.freedesktop.DBus.Hello`` bus registration, and thread-safe serial numbering:

* Exposes ``unique_name`` and ``server_guid`` obtained during ``start``.
* Decodes the ``Hello`` reply payload via ``DBusMessage#read_string_body`` and raises ``DBusError`` on ``MessageType::Error`` or unexpected message types.
* Guards ``@next_serial`` with ``Sync::Mutex`` and prevents wrap-around to ``0_u32``.

Signature Depth and Syntax Validation
=====================================

``SignatureValidator`` validates D-Bus type signatures prior to message serialization and during header parsing:

* Caps total signature length at ``MAX_LENGTH = 255`` bytes.
* Tracks ``array_depth`` and ``struct_depth`` independently up to ``MAX_DEPTH = 32`` per the D-Bus specification.
* Enforces that ``DICT_ENTRY`` (``{...}``) appears immediately inside an array, uses a basic type key, and contains a single complete value type.
* Rejects empty structs (``()``), unclosed containers, and unknown type codes with ``SignatureError``.

Error Hierarchy
===============

.. code-block:: crystal

   module Crystal::Dbus::Native
     class DBusError < Exception; end
     class AuthError < DBusError; end
     class SignatureError < DBusError; end
     class MessageError < DBusError; end
     class ConnectionClosedError < DBusError; end
   end

Security Controls Summary
=========================

.. list-table::
   :header-rows: 1
   :widths: 15 40 45

   * - Control ID
     - Vulnerability Vector
     - Mitigation Implemented
   * - SEC-01
     - Integer underflow or out-of-bounds read in ``cmsghdr`` parsing
     - Validate ``offset + hdr_len <= total_len`` and ``cmsg_len >= hdr_len`` in ``UInt64`` before subtraction
   * - SEC-02
     - Integer overflow in message payload allocation
     - Check ``body_len.to_u64 + fields_len.to_u64 > max_size.to_u64`` before allocating ``Bytes``
   * - SEC-03
     - Unbounded SASL line allocation
     - Enforce ``MAX_LINE_LENGTH = 4096`` in ``SASLAuthenticator.read_response``
   * - SEC-04
     - File descriptor leakage on ``execve`` or ``MSG_CTRUNC`` truncation
     - Pass ``MSG_CMSG_CLOEXEC`` to ``recvmsg`` and close all extracted FDs on ``MSG_CTRUNC`` or error
   * - SEC-05
     - Thread race or zero wrap-around in message serials
     - Synchronize ``next_serial`` with ``Sync::Mutex`` and skip ``0_u32``
   * - SEC-06
     - Unbounded container recursion in type signatures
     - Enforce ``MAX_LENGTH = 255`` and independent ``MAX_DEPTH = 32`` limits for arrays and structs

Verification Requirements
=========================

#. **Integer and Buffer Safety**: Verify oversized message headers, truncated bodies, and invalid header field lengths raise ``MessageError``.
#. **FD Passing**: Verify ``SCM_RIGHTS`` descriptor round-trip and ``MAX_FDS = 253`` bounds enforcement.
#. **SASL Handshake**: Verify UID hex encoding, ``NEGOTIATE_UNIX_FD``, read timeout, and oversized line rejection (``> 4096`` bytes).
#. **Connection Handshake**: Verify ``Hello`` registration, ``server_guid`` capture, error reply handling, and concurrent ``next_serial`` uniqueness.
#. **Signatures**: Verify basic types, nested arrays and structs up to depth 32, depth 33 rejection, empty struct ``()`` rejection, and dict entry validation.

References
==========

* D-Bus Specification 1.0
* Linux ``unix(7)``, ``sendmsg(2)``, ``recvmsg(2)``, and ``cmsg(3)`` manual pages
