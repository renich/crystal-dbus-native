=================
ROI & Key Metrics
=================

Measurable Objectives
---------------------

#. **Zero C-Library Runtime Dependencies**: Eliminate external ``libdbus-1`` linking requirements while supporting pure Crystal UNIX domain socket transport.
#. **Complete Wire & Body Type Safety**: Marshal and unmarshal all basic and nested D-Bus types (``Variant``, ``StructValue``, ``ObjectPath``, ``Signature``, ``UnixFD``, ``Array``, and ``Hash``) with strict 1, 2, 4, and 8-byte alignment enforcement.
#. **High-Concurrency Fiber Integration**: Enable non-blocking socket I/O, standard ``Properties``/``Introspectable`` client proxies, and multiplexed request-reply routing across concurrent Crystal fibers.
#. **Zero Initial Defects**: Enforce 100% pass rates across Crystal specs, Ameba static analysis, Flaw security scanning, and ``crstlint``/``rstcheck`` documentation gates.
