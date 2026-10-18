==============================================
ADR-001: Zero-Dependency Native D-Bus Protocol
==============================================

:Status: Accepted
:Date: 2026-10-18
:Deciders: Core Shard Architecture Team

Context
-------

Binding to ``libdbus-1`` introduces C library dependencies, thread-safety pitfalls, and opaque file descriptor handling that conflict with Crystal's non-blocking fiber event loop and static linking goals.

Decision
--------

#. **Zero Third-Party Runtime Dependencies**: Implement D-Bus wire framing (`DBusMessage`, `HeaderCodec`), body marshaling (`BodyCodec`, `Variant`), SASL ``EXTERNAL`` authentication (`SASLAuthenticator`), and ``SCM_RIGHTS`` file descriptor passing (`SecureFDPasser`) purely against the Crystal standard library and POSIX socket syscalls.
#. **Unbuffered Socket Framing**: Disable user-space read buffering on ``DBusConnection`` sockets so ``recvmsg`` with ``MSG_CMSG_CLOEXEC`` never loses ancillary ``SCM_RIGHTS`` control messages to read-ahead buffers.
#. **Strict Static Analysis**: Enforce zero linter suppressions across Ameba, Flaw, ``crstlint``, and ``rstcheck``.

Consequences
------------

* **Positive**: Zero C library linking overhead, deterministic ``SCM_RIGHTS`` descriptor lifetime, full Crystal event loop integration, and static compilation support.
* **Negative**: Wire alignment and container marshaling rules must be maintained directly in Crystal.
