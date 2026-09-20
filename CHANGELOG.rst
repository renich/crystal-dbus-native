=========
Changelog
=========

All notable changes to this project will be documented in this file.

The format is based on `Keep a Changelog <https://keepachangelog.com/en/1.1.0/>`_,
and this project adheres to `Semantic Versioning <https://semver.org/spec/v2.0.0.html>`_.

[Unreleased]
============

[0.1.2] - 2026-09-19
====================

.. rubric:: Security

- Hardened ``SecureFDPasser`` ancillary message control buffer with ``MSG_CMSG_CLOEXEC`` to prevent child descriptor leakage.
- Added ``MSG_CTRUNC`` detection in ``SecureFDPasser`` to abort on truncated control buffers.
- Hardened ``SignatureValidator`` to reject non-basic container and variant types as dictionary keys (``a{vs}``).
- Guaranteed socket timeout restoration in ``SASLAuthenticator`` via defensive ``ensure`` blocks.

.. rubric:: Added

- Completed D-Bus 16-byte fixed header serialization and parsing with 8-byte container boundary alignment.
- Added support for ``NEGOTIATE_UNIX_FD`` in ``SASLAuthenticator``.
- Integrated ``Crystal::EventLoop.current.wait_readable`` and ``wait_writable`` into socket retry loops for non-blocking I/O.
- Converted all tests to in-memory ``UNIXSocket.pair`` to eliminate filesystem race conditions and leaks.

.. rubric:: Refactored

- Extracted ``apply_field`` in ``DBusMessage`` to reduce cyclomatic complexity and improve modularity.

[0.1.1] - 2026-08-13
====================

.. rubric:: Fixed

- Removed standard library monkey-patching on ``UNIXSocket``.
- Added automatic file descriptor cleanup in ``recv_fds`` to prevent leaks on failure paths.
- Updated deprecated ``sleep 0.2`` calls to ``sleep 0.2.seconds``.

.. rubric:: Refactored

- Decomposed ``SignatureValidator.validate_single_type`` by extracting struct and dict entry sub-validators.

[0.1.0] - 2026-06-05
====================

.. rubric:: Added

- Initial orchestrated release of the architecture.
- Full TDD specifications with >80% code coverage.
- Code of Honor integration.
- FHS 3 compliant GNUmakefile.
- GitLab CI/CD Alpine pipeline.
