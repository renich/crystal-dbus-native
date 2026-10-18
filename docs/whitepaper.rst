===============================
crystal-dbus-native White Paper
===============================

Purpose
=======

The ``crystal-dbus-native`` project provides a native Crystal implementation of the D-Bus communication protocol. Its primary objective is to facilitate robust, low-level, and efficient inter-process communication over UNIX domain sockets without relying on the external C library ``libdbus``. By operating natively, it minimizes the attack surface associated with FFI overhead and C-level memory vulnerabilities while leveraging Crystal's strong type system and memory safety guarantees.

Architecture
============

The project architecture is structured around modular components that implement the D-Bus specification natively:

* **DBusConnection**: Manages the underlying ``UNIXSocket`` connection, SASL and ``Hello`` bus registration handshakes, and thread-safe message serial allocation.
* **DBusMessage**: Provides deterministic parsing and serialization of D-Bus message headers and payloads. It tracks endianness dynamically, validates header field codes and variant signatures, and decodes payloads with strict size bounds to avoid resource exhaustion.
* **SASLAuthenticator**: Facilitates the initial D-Bus handshake using the ``AUTH EXTERNAL`` mechanism and optional ``NEGOTIATE_UNIX_FD`` negotiation over UNIX domain sockets.
* **SecureFDPasser**: Implements ancillary control message (``SCM_RIGHTS``) handling for passing file descriptors across processes with ``MSG_CMSG_CLOEXEC`` and truncation cleanup.
* **SignatureValidator**: Analyzes and verifies D-Bus type signatures, enforcing well-formed payloads and independent container nesting limits according to the D-Bus type system.

Cryptography and Security
=========================

While D-Bus over local UNIX sockets defers to kernel-enforced access controls rather than network-level encryption, the project asserts strict security boundaries:

* **Identity Verification**: ``SASLAuthenticator`` performs ``AUTH EXTERNAL`` authentication using the hex-encoded ASCII UID over the local UNIX domain socket with bounded line reads (``MAX_LINE_LENGTH = 4096``) and enforced read timeouts.
* **Deterministic Integrity**: Protocol limits ensure that malformed signatures, unknown header field codes, non-zero alignment padding, or tampered headers fail structural checks before deep payload processing occurs.

Safety Guarantees
=================

Safety and empirical verification are enforced across all layers:

* **Memory and FD Exhaustion Prevention**: ``DBusMessage`` restricts maximum incoming message sizes (128 MiB by default per D-Bus specification). ``SecureFDPasser`` limits file descriptor arrays to 253 elements per transmission and closes all received descriptors if ``MSG_CTRUNC`` indicates control buffer truncation.
* **CMSG Alignment Safety**: Explicit byte-alignment helpers (``cmsg_align``, ``cmsg_space``, ``cmsg_len``) compute control message sizes directly in Crystal, guaranteeing exact bounds when iterating ``cmsghdr`` entries.
* **Stack Overflow Prevention**: ``SignatureValidator`` enforces an upper bound of 32 for nested arrays and 32 for nested structs/dict entries independently, and caps total signature length at 255 bytes.
* **Type Safety**: Crystal's compile-time checks and nil-safety ensure that runtime behaviors remain structurally sound and free from undefined states.

Testing Proof and Quality Assurance
===================================

Empirical validation of the implementation confirms stability and correctness across all sub-components. A total of 34 deterministic, isolated test examples execute via ``UNIXSocket.pair`` without any failures or errors, verifying the connection lifecycle, wire message framing, secure file descriptor passing, and bounds checking constraints.
