========================================
Crystal DBus-Native Project Master Roadmap
========================================

.. toctree::
   :maxdepth: 2
   :caption: Roadmap Phases

   roadmaps/phase-1-mvp
   roadmaps/phase-2-release

Executive Summary
=================
This document outlines the phased engineering milestones and release lifecycle for ``crystal-dbus-native``, delivering a zero-dependency, native UNIX-socket implementation of the D-Bus wire protocol and SASL authentication for Crystal.

Phase Breakdown
===============
* **Phase 1 (MVP Baseline)**: Native UNIX socket communication, SASL ``EXTERNAL`` authentication, message framing/marshalling, file descriptor passing (SCM_RIGHTS), and D-Bus signature validation.
* **Phase 2 (Crucible Refactoring & Release Stabilization)**: Purged monkey-patching, robust FD cleanup on error branches, signature validator decomposition, and v0.1.1 production release.
