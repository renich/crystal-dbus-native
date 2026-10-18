=============
User Personas
=============

Primary Stakeholders
--------------------

* **Systems & Cryptography Engineer**: Requires zero-copy or memory-safe ``SCM_RIGHTS`` file descriptor passing for secret service daemons, keyring agents, and systemd D-Bus APIs without C FFI vulnerabilities.
* **Crystal Application Developer**: Needs a clean, fiber-aware ``DBusConnection#call`` RPC interface with typed ``Value``/``Variant`` marshaling and non-blocking signal buffering.
* **Autonomous AI Coding Agent**: Relies on strict module boundaries, explicit type annotations, zero linter suppressions, and traceable specifications to extend and audit the shard safely.
