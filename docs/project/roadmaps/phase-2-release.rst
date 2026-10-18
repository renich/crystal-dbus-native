======================
Phase 2: Release 0.3.0
======================

Timeline & Objectives
---------------------

Decompose header serialization into ``HeaderCodec``, implement the general-purpose ``BodyCodec`` and ``Variant`` type system, add ``DBusConnection#call`` RPC correlation with signal buffering, and align the Sphinx documentation suite.

Milestones & Deliverables
-------------------------

* **Milestone 2.1: Header & Body Codec Architecture** (Fulfills ``[FUNC-001]``, ``[FUNC-003]``):

  - [x] Extract ``HeaderCodec`` from ``DBusMessage`` so every module remains under 220 lines.
  - [x] Implement ``Variant``, ``StructValue``, ``ObjectPath``, ``Signature``, ``UnixFD``, and ``BodyCodec``.
  - [x] Enforce 1, 2, 4, and 8-byte alignment rules including empty arrays of 8-byte elements (``a{sv}``, ``a(ii)``).

* **Milestone 2.2: RPC Correlation, FD Transport, & Docs** (Fulfills ``[FUNC-005]``, ``[FUNC-006]``):

  - [x] Add ``DBusConnection#call``, ``poll_signal``, ``send`` with FDs, and ``receive_with_fds``.
  - [x] Achieve 100% pass rate across ``crystal spec``, Ameba, Flaw, ``crstlint``, ``rstcheck``, and Sphinx ``dirhtml``.
