================================================================
ADR-002: Phase 2 Multiplexed Fiber Reply Router & Client Proxies
================================================================

:Status: Accepted
:Date: 2026-10-18
:Deciders: Core Shard Architecture Team

Context
-------

Phase 1 (``v0.3.0``) delivers synchronous request-reply correlation in ``DBusConnection#call`` with interleaved ``Signal`` queueing under a single transport mutex. When multiple Crystal fibers share a single ``DBusConnection`` and invoke ``#call`` concurrently, holding the socket read lock across an entire round-trip introduces head-of-line blocking. Furthermore, consumers interacting with standard freedesktop services repeatedly construct ``org.freedesktop.DBus.Properties`` and ``org.freedesktop.DBus.Introspectable`` method calls by hand.

Decision
--------

#. **Typed Standard Interface Proxies** (Fulfills ``[FUNC-006]``/``[TECH-006]``):
   Introduce ``PropertiesProxy`` (``Get``, ``Set``, ``GetAll``, and ``PropertiesChanged`` decoding) and ``IntrospectableProxy`` (``Introspect``) in Phase 2 (``v0.3.1``) on top of ``DBusConnection`` and ``BodyCodec`` without adding external dependencies.

#. **Multiplexed Fiber Reply Router & Match-Rule Subscriptions** (Fulfills ``[FUNC-007]``/``[TECH-007]``):
   Introduce a background reader fiber in Phase 2 (``v0.3.1``) that demultiplexes inbound ``METHOD_RETURN`` and ``ERROR`` frames by ``reply_serial`` into per-call buffered ``Channel(DBusMessage).new(1)`` channels stored in a mutex-protected ``Hash(UInt32, Channel(DBusMessage))`` map, and dispatches ``SIGNAL`` frames to bounded ``Channel(DBusMessage).new(64)`` subscriber channels registered via ``org.freedesktop.DBus.AddMatch`` and ``RemoveMatch``. ``DBusConnection#call`` removes ``serial`` from ``Hash(UInt32, Channel(DBusMessage))`` under ``@mutex`` inside an ``ensure`` block on return, timeout, cancellation, or connection close so the reader fiber never blocks or leaks channels.

Consequences
------------

* **Positive**: Concurrent Crystal fibers execute ``DBusConnection#call`` over a shared socket without head-of-line blocking, and standard D-Bus property and introspection operations require single method calls.
* **Negative**: Connection teardown (``#close``) must deterministically close all pending reply and signal subscription channels so blocked fibers wake up with ``ConnectionClosedError``.
