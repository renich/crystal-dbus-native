=========
Changelog
=========

All notable changes to this project will be documented in this file.

The format is based on `Keep a Changelog <https://keepachangelog.com/en/1.1.0/>`_,
and this project adheres to `Semantic Versioning <https://semver.org/spec/v2.0.0.html>`_.

[Unreleased]
============

[0.1.1] - 2026-08-13
====================

Fixed
~~~~~
- Removed standard library monkey-patching on ``UNIXSocket``.
- Added automatic file descriptor cleanup in ``recv_fds`` to prevent leaks on failure paths.
- Updated deprecated ``sleep 0.2`` calls to ``sleep 0.2.seconds``.

Refactored
----------
- Decomposed ``SignatureValidator.validate_single_type`` by extracting struct and dict entry sub-validators.

[0.1.0] - 2026-06-05
====================

Added
-----
- Initial orchestrated release of the architecture.
- Full TDD specifications with >80% code coverage.
- Code of Honor integration.
- FHS 3 compliant GNUmakefile.
- GitLab CI/CD Alpine pipeline.
