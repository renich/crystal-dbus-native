Architecture and Design
=======================

The ``crystal-dbus-native`` library provides a native Crystal implementation of the D-Bus protocol. Key architectural decisions prioritize security, stability, and platform correctness.

Core Components
---------------

The library is structured into the following independent components under the ``Crystal::Dbus::Native`` namespace:

* **SignatureValidator**: Validates D-Bus type signatures, ensuring they are well-formed and strictly enforcing structural constraints (e.g., maximum depth of 32, maximum length of 255).
* **SecureFDPasser**: Manages file descriptor passing via ``SCM_RIGHTS``. It sets ``FD_CLOEXEC`` on received descriptors and restricts operations to a maximum limit (e.g., 253 FDs).
* **DBusMessage**: Parses the binary D-Bus message headers and bodies, enforcing correct endianness handling and preventing messages from exceeding predefined maximum sizes.
* **SASLAuthenticator**: Performs D-Bus EXTERNAL authentication. It processes ``SCM_CREDENTIALS`` and guarantees bounded response reading via strict line length limits and timeouts.
* **DBusConnection**: Coordinates overall protocol interaction, managing the background reader loop, routing responses to pending calls, and providing a clean shutdown mechanism.

Implementation Highlights
-------------------------

* **Atomic FD_CLOEXEC**: Uses ``MSG_CMSG_CLOEXEC`` to ensure file descriptors are not leaked to child processes.
* **Control Message Iteration**: Implements standard ``CMSG_FIRSTHDR`` and ``CMSG_NXTHDR`` macros for parsing control messages correctly.
* **Timeouts**: Enforces timeouts on all socket operations to prevent indefinite hangs.
* **Signature Depth Validation**: Validates the depth of D-Bus signatures before parsing to mitigate stack exhaustion or memory exhaustion attacks.

Design Decisions
----------------

SCM_CREDENTIALS Verification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Why**: To prevent UID spoofing during D-Bus authentication.

**Trade-off**: Introduces platform-specific code (Linux sockets) but is fundamentally required to avoid authentication bypass.
