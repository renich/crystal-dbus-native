=========
Changelog
=========

All notable changes to this project will be documented in this file.

The format is based on `Keep a Changelog <https://keepachangelog.com/en/1.1.0/>`__,
and this project adheres to `Semantic Versioning <https://semver.org/spec/v2.0.0.html>`__.

[Unreleased]
============

[0.3.0] - 2026-10-18
====================

.. rubric:: Added

- Added ``Variant``, ``StructValue``, ``ObjectPath``, ``Signature``, ``UnixFD``, and ``Value`` union types in ``src/crystal-dbus-native/variant.cr``.
- Added general-purpose D-Bus body marshaler and unmarshaler (``BodyCodec.encode`` and ``BodyCodec.decode``) with strict 1, 2, 4, and 8-byte alignment enforcement, including empty arrays of 8-byte elements (``a{sv}``, ``a(ii)``).
- Added ``DBusMessage#encode_body``, ``DBusMessage#decode_body``, and ``DBusMessage.parse_from_header``.
- Added ``DBusConnection#call`` RPC correlation with interleaved ``Signal`` buffering (``DBusConnection#poll_signal``), ``DBusConnection#send`` with ``fds``, and ``DBusConnection#receive_with_fds``.
- Added ``SignatureValidator.split_types`` and ``SignatureValidator.validate_single``.
- Added modular Sphinx documentation suite (``docs/business/``, ``docs/functional/``, ``docs/technical/``, ``docs/adrs/``, ``docs/project/``, and ``docs/user/``) along with ``LICENSE-DOCS``, ``CODE_OF_HONOR.rst``, and ``.crstlint.yaml``.

.. rubric:: Changed

- Extracted D-Bus header field array (``a(yv)``) parsing and serialization from ``DBusMessage`` into ``HeaderCodec`` so all source files remain under 220 lines and all methods under 25 lines.
- Disabled user-space read buffering on ``DBusConnection`` sockets to preserve ``SCM_RIGHTS`` ancillary control messages across stream reads.

[0.2.0] - 2026-10-18
====================

.. rubric:: Security

- Enforced ``SASLAuthenticator::MAX_LINE_LENGTH`` (4096 bytes) during SASL handshake reads to prevent unbounded memory growth.
- Fixed ``SecureFDPasser.recv_fds`` to extract and close received file descriptors before raising on ``MSG_CTRUNC`` ancillary truncation.
- Added multi-header ``cmsghdr`` iteration with strict bounds checks and ``Errno::EINTR`` retry loops in ``SecureFDPasser``.
- Hardened ``DBusMessage.parse`` to strictly validate endianness (``'l'`` or ``'B'``), reject ``serial == 0``, verify zeroed alignment padding, validate header field codes and variant signatures, and enforce UTF-8/NUL bounds on header strings and signatures.

.. rubric:: Added

- Added ``DBusMessage#read_string_body`` with 64-bit bounds validation and message-endianness decoding.
- Added ``DBusConnection#server_guid`` getter and ``negotiate_unix_fd`` support in ``DBusConnection#start``.
- Added ``UNIX_FDS`` header field serialization in ``DBusMessage#serialize``.
- Added Crystal API docstrings across all public modules, classes, enums, constants, and methods.

.. rubric:: Changed

- Computed ``DBusMessage#body_length`` dynamically from ``@body.size`` to eliminate mutable state desynchronization.
- Updated ``SignatureValidator`` to track ``ARRAY`` and ``STRUCT``/``DICT_ENTRY`` nesting depths independently up to ``MAX_DEPTH`` (32).
- Overhauled ``GNUmakefile``, ``.ameba.yml``, ``.gitlab-ci.yml``, and technical documentation to align with Crystal 1.21+ and strict RST linting standards.

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

.. rubric:: Changed

- Extracted ``apply_field`` in ``DBusMessage`` to reduce cyclomatic complexity and improve modularity.

[0.1.1] - 2026-08-13
====================

.. rubric:: Fixed

- Removed standard library monkey-patching on ``UNIXSocket``.
- Added automatic file descriptor cleanup in ``recv_fds`` to prevent leaks on failure paths.
- Updated deprecated ``sleep 0.2`` calls to ``sleep 0.2.seconds``.

.. rubric:: Changed

- Decomposed ``SignatureValidator.validate_single_type`` by extracting struct and dict entry sub-validators.

[0.1.0] - 2026-06-05
====================

.. rubric:: Added

- Initial orchestrated release of the architecture.
- Full TDD specifications with >80% code coverage.
- Code of Honor integration.
- FHS 3 compliant GNUmakefile.
- GitLab CI/CD Alpine pipeline.
