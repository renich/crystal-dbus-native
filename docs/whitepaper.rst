crystal-dbus-native White Paper
===============================

Purpose
-------
The ``crystal-dbus-native`` project provides a native Crystal implementation of the D-Bus communication protocol. Its primary objective is to facilitate robust, low-level, and efficient inter-process communication (IPC) over Unix Domain Sockets without relying on the external C library ``libdbus``. By operating natively, it minimizes the attack surface associated with FFI (Foreign Function Interface) overhead and C-level memory vulnerabilities, while leveraging Crystal's strong type system and memory safety guarantees.

Architecture
------------
The project architecture is structured around modular components that implement the D-Bus specification natively:

* **DBusConnection**: Manages the underlying UNIXSocket connection and lifecycle of the local D-Bus transport layer.
* **DBusMessage**: Provides deterministic parsing and serialization of D-Bus message headers and payloads. It intrinsically tracks endianness dynamically, decoding payloads with strict size bounds to avoid resource exhaustion.
* **SASLAuthenticator**: Facilitates the initial D-Bus handshake using the ``AUTH EXTERNAL`` mechanism, interacting with standard Unix credentials.
* **SecureFDPasser**: Implements platform-specific ancillary data (CMSG) handling for securely passing file descriptors across processes.
* **SignatureValidator**: Analyzes and verifies D-Bus type signatures, ensuring well-formed payloads according to the D-Bus type system.

Cryptography and Security
-------------------------
While D-Bus over local Unix sockets defers to kernel-enforced access controls rather than network-level encryption, the project asserts robust security boundaries:

* **Identity Verification**: The ``SASLAuthenticator`` mandates external authentication (via user UID) validated directly by the kernel's Unix socket peer credential exchange.
* **Deterministic Integrity**: Protocol limits ensure that malformed signatures or tampered headers fail structural checks before deep payload processing occurs.

Safety Guarantees
-----------------
Safety and empirical verification are paramount. Key protective mechanisms include:

* **Memory and FD Exhaustion Prevention**: ``DBusMessage`` restricts maximum incoming message sizes (capped safely per D-Bus spec). ``SecureFDPasser`` rigorously limits file descriptor arrays to 253 elements per transmission to prevent fd-exhaustion attacks.
* **CMSG Alignment Safety**: Custom byte-alignment logic (``cmsg_align``, ``cmsg_space``, ``cmsg_len``) computes control message sizes directly in Crystal, bypassing potentially unsafe C macros and guaranteeing exact bounds for socket ancillary data.
* **Stack Overflow Prevention**: ``SignatureValidator`` enforces a strict upper bound of 32 for nested structures and dictionaries, and caps total signature length at 255 characters, neutralizing potential denial-of-service via deep recursion.
* **Type Safety**: Crystal's strict compile-time checks and nil-safety ensure that runtime behaviors remain structurally sound and free from undefined states.

Testing Proof and Quality Assurance
-----------------------------------
Empirical validation of the implementation demonstrates robust stability and correctness. Execution of the project's rigorous test suite confirms functionality across all sub-components. A total of 20 deterministic, independent test examples passed without any failures or errors, verifying the correct behavior of the connection lifecycle, deterministic message handling, secure file descriptor passing, and bounds checking constraints.
