=================
Core Requirements
=================

Functional Requirements
-----------------------

* **[FUNC-001] D-Bus Wire Message Framing & Header Codec**:
  The shard must parse and serialize D-Bus protocol v1 16-byte fixed headers and ``a(yv)`` header field arrays (`HeaderCodec` and `DBusMessage`) in both little-endian and big-endian formats, enforcing 8-byte header alignment and payload size bounds.

* **[FUNC-002] Recursive Signature Validation**:
  The shard must validate D-Bus type signatures (`SignatureValidator`) up to 255 bytes and independent 32-level nesting depths for arrays and structs, rejecting empty structs and non-basic dictionary keys.

* **[FUNC-003] General-Purpose Body Marshaler & Unmarshaler**:
  The shard must encode and decode arbitrary D-Bus message bodies (`BodyCodec` and `Variant`) across all primitive types, ``ObjectPath``, ``Signature``, ``UnixFD``, ``Variant``, ``StructValue``, ``Array(Value)``, and ``Hash(Value, Value)`` while honoring 1, 2, 4, and 8-byte alignment boundaries including empty arrays of 8-byte elements.

* **[FUNC-004] SASL EXTERNAL Authentication & FD Negotiation**:
  The shard must authenticate over ``UNIXSocket`` via SASL ``EXTERNAL`` (`SASLAuthenticator`) with configurable timeouts, 4096-byte line limits, and optional ``NEGOTIATE_UNIX_FD`` negotiation.

* **[FUNC-005] Secure SCM_RIGHTS File Descriptor Passing**:
  The shard must transmit and receive up to 253 file descriptors per message (`SecureFDPasser`) using ``MSG_CMSG_CLOEXEC`` and automatically close extracted descriptors if ``MSG_CTRUNC`` truncation or parsing errors occur.

* **[FUNC-006] Connection RPC & Signal Buffering**:
  The shard must provide thread-safe serial allocation, ``DBusConnection#call`` request-reply correlation, interleaved ``Signal`` queuing via ``poll_signal``, and ``send``/``receive_with_fds`` transport operations.
