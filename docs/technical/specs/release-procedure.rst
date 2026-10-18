=========================================
Release Procedure and Versioning Playbook
=========================================

Overview
--------

This document defines the deterministic, repeatable release workflow for ``crystal-dbus-native``. It enforces Semantic Versioning, Keep a Changelog 1.1.0 compliance, multi-file version alignment, local pre-push linting, and signed GPG Git tags.

Requirement Mapping
-------------------

Fulfills ``[FUNC-001]`` through ``[FUNC-006]``.

Multi-File Version Alignment Checklist
--------------------------------------

Prior to tagging any release, the version string (e.g. ``0.3.0``) must be updated in four locations across the codebase:

#. **`shard.yml <../../../shard.yml>`__**:

   .. code-block:: yaml

      version: 0.3.0

#. **`src/crystal-dbus-native.cr <../../../src/crystal-dbus-native.cr>`__**:

   .. code-block:: crystal

      VERSION = "0.3.0"

#. **`docs/conf.py <../../conf.py>`__**:

   .. code-block:: python

      release = '0.3.0'

#. **`CHANGELOG.rst <../../../CHANGELOG.rst>`__**:
   Promote items from ``[Unreleased]`` under a new version header using ``.. rubric::`` sections:

   .. code-block:: rst

      [0.3.0] - 2026-10-18
      ====================

      .. rubric:: Added

      - Added general-purpose D-Bus body marshaler and RPC call correlation.

Step-by-Step Release Execution Playbook
---------------------------------------

#. Execute the full test suite, static analyzers, and documentation linters locally:

   .. code-block:: bash

      make all
      make doc-check
      make docs

#. Stage and commit version changes adhering to Conventional Commit standards:

   .. code-block:: bash

      git add shard.yml src/crystal-dbus-native.cr docs/conf.py CHANGELOG.rst
      git commit -S -s -m "chore(release): bump version to 0.3.0"

#. Create a GPG-signed annotated Git tag and push to GitLab:

   .. code-block:: bash

      git tag -s v0.3.0 -m "Release v0.3.0"
      git push origin master --tags
