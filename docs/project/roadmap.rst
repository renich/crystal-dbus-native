==========================================
Crystal DBus-Native Project Master Roadmap
==========================================

Executive Summary
=================

This document outlines the phased engineering milestones and release lifecycle for ``crystal-dbus-native``, delivering a zero-dependency, native UNIX-socket implementation of the D-Bus wire protocol and SASL authentication for Crystal.

Roadmap Phases
--------------

* `Phase 1: Native D-Bus Wire Protocol and SASL Core MVP <roadmaps/phase-1-mvp.rst>`__
* `Phase 2: Crucible Protocol Refactoring and Release Stabilization <roadmaps/phase-2-release.rst>`__

Phase Breakdown
===============

* **Phase 1 — MVP Baseline**: Native UNIX socket communication, SASL ``EXTERNAL`` authentication, message framing and marshalling, file descriptor passing (``SCM_RIGHTS``), and D-Bus signature validation.
* **Phase 2 — Crucible Refactoring and Release Stabilization**: Purged monkey-patching, deterministic FD cleanup on error and truncation branches, signature validator decomposition, and ``v0.1.2`` stabilization.
* **Phase 3 — Echelon and Crucible v0.2.0 Hardening**: Strict wire framing and header validation, ``UNIX_FDS`` serialization, bounded SASL line reads, multi-header ``cmsghdr`` FD extraction before ``MSG_CTRUNC`` evaluation, independent array/struct depth limits, and lean CI/CD pipeline.
