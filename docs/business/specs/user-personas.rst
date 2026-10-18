=============
User Personas
=============

Primary Stakeholders
--------------------

* **Systems & Cryptography Engineer**: Requires memory-safe ``SCM_RIGHTS`` file descriptor passing for secret service daemons, keyring agents, and systemd D-Bus APIs without C FFI vulnerabilities.
* **Crystal Application Developer**: Requires a clean, fiber-aware ``DBusConnection#call`` RPC interface with typed ``Value``/``Variant`` marshaling, standard ``Properties`` and ``Introspectable`` client proxies, and asynchronous signal subscriptions.
* **Autonomous AI Coding Agent**: Relies on strict module boundaries, explicit type annotations, zero linter suppressions, and 1:1 bidirectional requirement traceability across specifications and roadmaps.
