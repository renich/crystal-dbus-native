============
Contributing
============

Thank you for your interest in contributing to ``crystal-dbus-native``. We welcome contributions from human engineers and autonomous agents who share our commitment to software excellence, security rigor, and empirical verification.

Code of Honor
=============

All contributors are expected to uphold the principles defined in `CODE_OF_HONOR.rst <CODE_OF_HONOR.rst>`__. We build resilient, well-tested software, demand intellectual honesty, operate transparently, and verify all library behaviors empirically.

Development Guidelines
======================

#. **Test-Driven Development**: All new features or bug fixes must be accompanied by relevant specifications in ``spec/``.
#. **Coverage**: The test suite must maintain strict ``>= 80%`` coverage.
#. **Linting**: We enforce a strict 120-character line limit, maximum 220 lines per file, maximum 25 lines per method, and maximum cyclomatic complexity of 10. Run ``make lint`` and ``make doc-check`` prior to committing. No linter suppressions (``# ameba:disable`` or ``# flaw:disable``) are allowed.
#. **Build System**: All tasks (testing, linting, building docs) must utilize the project ``GNUmakefile``.

Pull Request Process
====================

#. Create a descriptive branch from ``master``.
#. Ensure your changes compile and pass ``make all``, ``make doc-check``, and ``make docs``.
#. Update ``CHANGELOG.rst`` following the ``Keep a Changelog 1.1.0`` guidelines.
#. Add your ``Signed-off-by`` trailer to your commits.
