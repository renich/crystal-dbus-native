===================================
Contributing to crystal-dbus-native
===================================

Thank you for your interest in contributing to ``crystal-dbus-native``. We welcome contributions from human engineers and autonomous agents who share our commitment to software excellence, security rigor, and empirical verification.

Code of Honor
=============

All contributors must uphold the principles defined in `CODE_OF_HONOR.rst <CODE_OF_HONOR.rst>`__. We build resilient, well-tested software, demand intellectual honesty, operate transparently, and verify all library behaviors empirically.

Development Workflow
====================

Prerequisites
-------------

* `Crystal <https://crystal-lang.org/>`__ (>= 1.21.0)
* `GNU Make <https://www.gnu.org/software/make/>`__
* `cRSTLint <https://gitlab.com/renich/crstlint>`__ (for documentation linting)

Setting Up the Workspace
------------------------

#. Clone the repository:

   .. code-block:: bash

      git clone git@gitlab.com:renich/crystal-dbus-native.git
      cd crystal-dbus-native

#. Build the linter binaries and install development dependencies:

   .. code-block:: bash

      make deps

#. Verify the test suite, static analysis, and documentation checks:

   .. code-block:: bash

      make check

Testing and Quality Standards
=============================

We adhere strictly to Test-Driven Development and the principle of **Do Not Assume; Always Verify**.

Running Checks
--------------

* **Run test suite**:

   .. code-block:: bash

      make test

* **Run static linters** (Ameba & Flaw):

   .. code-block:: bash

      make lint

* **Validate RST Documentation**:

   .. code-block:: bash

      make doc-check

Coding Constraints
------------------

#. Every Crystal file in ``src/`` and ``spec/`` must remain at or under 220 lines, every method at or under 25 lines, and cyclomatic complexity at or under 10.
#. Maximum line length is 120 characters.
#. Inline or global linter suppressions (``# ameba:disable`` or ``# flaw:disable``) are strictly prohibited.

Git Commit Standards
====================

We enforce the Conventional Commits specification:

* ``feat(codec): add general-purpose D-Bus body marshaler``
* ``fix(fd): close extracted descriptors on MSG_CTRUNC truncation``
* ``docs(adrs): record decision on multiplexed fiber reply router``
* ``test(spec): add big-endian dictionary alignment specs``

All commits must be signed and authored with full technical ownership.
