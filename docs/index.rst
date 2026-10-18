==================================
Crystal D-Bus Native Documentation
==================================

**Zero-Dependency Native D-Bus Wire Protocol, Marshaler, SASL Handshake, and SCM_RIGHTS FD Passing for Crystal.**

Welcome to the official documentation portal for ``crystal-dbus-native``.

Documentation Architecture
--------------------------

.. list-table::
   :widths: 25 45 30
   :header-rows: 1

   * - Guide
     - Purpose & Scope
     - Entrypoint
   * - **Business & Strategy**
     - Strategic vision, ecosystem goals, and user personas.
     - `Business Specifications <business/spec.rst>`__
   * - **Functional Specifications**
     - Requirements [FUNC-001]..[FUNC-006], behavioral contracts, and interfaces.
     - `Functional Specifications <functional/spec.rst>`__
   * - **Technical Architecture**
     - Wire framing, body marshaling, SCM_RIGHTS security, threat model, and release strategy.
     - `Technical Architecture <technical/spec.rst>`__
   * - **Architecture Decisions**
     - Immutable Architecture Decision Records and trade-off analyses.
     - `Architecture Decisions <adrs/index.rst>`__
   * - **Project Roadmap**
     - Sequenced phase milestones, delivery tracking, and verification matrices.
     - `Project Roadmap <project/roadmap.rst>`__
   * - **User Guides**
     - Integration guides, code examples, and API tutorials.
     - `User Manual <user/index.rst>`__
   * - **Crystal API Reference**
     - Compiler-generated API documentation covering all classes, structs, and modules.
     - `Crystal API Reference <technical/api/index.html>`__

.. toctree::
   :maxdepth: 2
   :caption: Documentation Suite

   business/spec
   functional/spec
   technical/spec
   adrs/index
   project/roadmap
   user/index

Indices and tables
------------------

* :ref:`genindex`
* :ref:`search`
