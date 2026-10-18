=================
Core Requirements
=================

Functional Requirements
-----------------------

* **[FUNC-001] SASL EXTERNAL Authentication and NEGOTIATE_UNIX_FD Handshake**:
  The shard must authenticate over ``UNIXSocket`` via SASL ``EXTERNAL`` in ``SASLAuthenticator`` using the hex-encoded effective host UID, enforce a 4096-byte line limit and configurable socket timeout, negotiate ``NEGOTIATE_UNIX_FD`` when requested, and complete the ``org.freedesktop.DBus.Hello`` registration in ``DBusConnection#start`` to return the assigned unique bus name.

* **[FUNC-002] Recursive D-Bus Type Signature Validation**:
  The shard must validate D-Bus type signatures via ``SignatureValidator.validate``, ``SignatureValidator.validate_single``, and ``SignatureValidator.split_types``, enforcing the 255-byte maximum length, single-complete-type grammar, non-empty struct constraints, basic-type dictionary key restrictions, and independent 32-level container nesting depth limits for ``ARRAY`` and ``STRUCT``/``DICT_ENTRY`` scopes.

* **[FUNC-003] Binary Message Header and Body Marshaling**:
  The shard must parse and serialize D-Bus wire protocol v1 16-byte fixed headers and ``a(yv)`` header field arrays via ``HeaderCodec`` and ``DBusMessage`` alongside general-purpose payload bodies via ``BodyCodec``, ``Variant``, ``StructValue``, ``ObjectPath``, ``Signature``, and ``UnixFD``. Both little-endian and big-endian formats must enforce 1, 2, 4, and 8-byte alignment boundaries, including 8-byte element alignment padding for empty arrays such as ``a{sv}`` and ``a(ii)``.

* **[FUNC-004] Out-of-Band UNIX File Descriptor Passing**:
  The shard must transmit and receive up to 253 UNIX file descriptors per message over ``UNIXSocket`` via ``SecureFDPasser`` using ``sendmsg`` and ``recvmsg`` with ``SCM_RIGHTS`` ancillary control messages and ``MSG_CMSG_CLOEXEC``. On ``MSG_CTRUNC`` ancillary truncation or message framing errors, all extracted file descriptors must be closed immediately before raising ``MessageError``.

* **[FUNC-005] Synchronous RPC Method Invocation and Signal Queueing**:
  The shard must provide thread-safe non-zero 32-bit serial allocation, synchronous request-reply method invocation via ``DBusConnection#call``, automatic error conversion on ``MessageType::ERROR``, interleaved ``Signal`` buffering accessible via ``DBusConnection#poll_signal``, and ``DBusConnection#send``/``DBusConnection#receive_with_fds`` operations synchronized by ``Sync::Mutex``.

* **[FUNC-006] Typed org.freedesktop.DBus.Properties and Introspectable Client Proxies**:
  In Phase 2 ``v0.4.0``, the shard will provide high-level client proxies for ``org.freedesktop.DBus.Properties`` supporting typed ``Get``, ``Set``, and ``GetAll`` method calls plus ``PropertiesChanged`` signal decoding, alongside an ``org.freedesktop.DBus.Introspectable`` client proxy wrapping ``Introspect`` XML retrieval.

* **[FUNC-007] Asynchronous Match-Rule Signal Subscriptions and Multiplexed Fiber Reply Router**:
  In Phase 2 ``v0.4.0``, the shard will provide a background reader fiber and ``Hash(UInt32, Channel(DBusMessage))`` pending reply demultiplexer so multiple Crystal fibers execute ``DBusConnection#call`` concurrently without head-of-line blocking, paired with ``org.freedesktop.DBus.AddMatch`` and ``RemoveMatch`` channel-based signal subscriptions. Per-call reply channels must use buffered ``Channel(DBusMessage).new(1)``, signal subscription channels must use bounded ``Channel(DBusMessage).new(64)``, and ``DBusConnection#call`` must remove ``serial`` from ``Hash(UInt32, Channel(DBusMessage))`` under ``@mutex`` inside an ``ensure`` block on return, timeout, cancellation, or connection close so the reader fiber never blocks or leaks channels.

Traceability Matrix
-------------------

.. list-table::
   :header-rows: 1
   :widths: 15 15 40 30

   * - Requirement ID
     - Target Release
     - Fulfilling Technical Specs
     - Roadmap Task Mapping
   * - ``[FUNC-001]``
     - ``v0.3.0``
     - ``[TECH-001]``, ``[TECH-005]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/threat-model`)
     - ``TASK-101`` (:doc:`../../project/roadmaps/phase-1-mvp`)
   * - ``[FUNC-002]``
     - ``v0.3.0``
     - ``[TECH-002]``, ``[TECH-004]``, ``[TECH-005]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/coding-standards`, :doc:`../../technical/specs/threat-model`)
     - ``TASK-102`` (:doc:`../../project/roadmaps/phase-1-mvp`)
   * - ``[FUNC-003]``
     - ``v0.3.0``
     - ``[TECH-002]``, ``[TECH-005]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/threat-model`)
     - ``TASK-104`` (:doc:`../../project/roadmaps/phase-1-mvp`)
   * - ``[FUNC-004]``
     - ``v0.3.0``
     - ``[TECH-003]``, ``[TECH-005]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/threat-model`)
     - ``TASK-103`` (:doc:`../../project/roadmaps/phase-1-mvp`)
   * - ``[FUNC-005]``
     - ``v0.3.0``
     - ``[TECH-001]``, ``[TECH-004]``, ``[TECH-005]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/coding-standards`, :doc:`../../technical/specs/release-procedure`)
     - ``TASK-105`` (:doc:`../../project/roadmaps/phase-1-mvp`)
   * - ``[FUNC-006]``
     - ``v0.4.0``
     - ``[TECH-004]``, ``[TECH-006]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/coding-standards`)
     - ``TASK-203``, ``TASK-204`` (:doc:`../../project/roadmaps/phase-2-enhancement`)
   * - ``[FUNC-007]``
     - ``v0.4.0``
     - ``[TECH-005]``, ``[TECH-007]`` (:doc:`../../technical/specs/architecture-overview`, :doc:`../../technical/specs/threat-model`)
     - ``TASK-201``, ``TASK-202`` (:doc:`../../project/roadmaps/phase-2-enhancement`)
