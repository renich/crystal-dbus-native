=======================
Architecture and Design
=======================

The ``crystal-dbus-native`` library provides a native Crystal implementation of the D-Bus wire protocol over UNIX domain sockets. Key architectural decisions prioritize security, determinism, and zero C-library dependencies.

Core Components
===============

The library is structured into five primary components under the ``Crystal::Dbus::Native`` namespace:

* **SignatureValidator**: Validates D-Bus type signatures, ensuring they are well-formed and strictly enforcing structural constraints (maximum byte length of 255, plus independent nesting limits of 32 for ``ARRAY`` and 32 for ``STRUCT``/``DICT_ENTRY`` containers).
* **SecureFDPasser**: Manages file descriptor passing via ``SCM_RIGHTS`` ancillary control messages. It applies ``MSG_CMSG_CLOEXEC`` on received descriptors, iterates all ``cmsghdr`` entries with bounds checks, closes descriptors on ``MSG_CTRUNC`` truncation, and restricts operations to ``MAX_FDS`` (253).
* **DBusMessage**: Parses and serializes binary D-Bus message headers and bodies, enforcing endianness validation (``Endianness::Little`` and ``Endianness::Big``), non-zero serial numbers, header field code/signature verification, zeroed alignment padding, and maximum message size bounds.
* **SASLAuthenticator**: Performs D-Bus ``EXTERNAL`` authentication using the hex-encoded ASCII UID and optional ``NEGOTIATE_UNIX_FD`` negotiation, enforcing bounded line reads (``MAX_LINE_LENGTH = 4096``) and restoring socket timeouts via ``ensure``.
* **DBusConnection**: Coordinates the ``UNIXSocket`` transport, SASL authentication, ``org.freedesktop.DBus.Hello`` bus registration handshake, and thread-safe non-zero serial allocation via ``Sync::Mutex``.

Implementation Highlights
=========================

* **Atomic Close-on-Exec**: Uses ``MSG_CMSG_CLOEXEC`` in ``recvmsg`` so received file descriptors are atomically marked close-on-exec by the kernel.
* **Control Message Iteration**: Iterates all ``LibC::Cmsghdr`` headers in ``msg_control`` using aligned offsets and strict ``UInt64`` bounds checks before reading ``SCM_RIGHTS`` payloads.
* **Socket Timeouts and Event Loop Integration**: Enforces read timeouts during SASL handshakes and integrates with ``Crystal::EventLoop.current`` on ``Errno::EAGAIN``/``Errno::EWOULDBLOCK`` and ``Errno::EINTR`` retry loops.
* **Stack-Allocated Header Framing**: Uses ``uninitialized StaticArray(UInt8, 16)`` for reading fixed 16-byte D-Bus message headers without heap allocation overhead.

Design Decisions
================

SASL EXTERNAL over UNIX Domain Sockets
--------------------------------------

**Why**: Local D-Bus message buses (``system`` and ``session``) authenticate local peers using the ``EXTERNAL`` mechanism over UNIX domain sockets by transmitting the ASCII UID in hexadecimal alongside the initial NUL byte.

**Trade-off**: Specializes transport to ``UNIXSocket``, eliminating external ``libdbus`` FFI complexity while matching standard Linux system and session bus deployments.
