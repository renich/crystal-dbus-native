================
Coding Standards
================

Requirement Mapping
-------------------

Fulfills ``[FUNC-002]``, ``[FUNC-005]``, and ``[FUNC-006]``.

Technical Specification
-----------------------

* **[TECH-004] Zero-Suppression Static Analysis, Modularity Bounds, and Concurrency Safety** (Fulfills ``[FUNC-002]``, ``[FUNC-005]``, ``[FUNC-006]``):
  All source and specification files must satisfy the strict engineering constraints enumerated below.

Core Directives
---------------

#. **Strict Static Analysis**:
   Full default rule sets for Ameba and Flaw are enabled. Global rule suppression in ``.ameba.yml`` and inline ``# ameba:disable`` or ``# flaw:disable`` annotations are strictly prohibited.

#. **Modularity & Complexity Limits**:
   Every Crystal source and spec file must remain at or under 220 lines, every method at or under 25 lines, and cyclomatic complexity at or under 10.

#. **Defensive Nil Handling & Explicit Types**:
   Never call ``.not_nil!``. All method parameters and return types must carry explicit type annotations, using type narrowing with ``if``, ``case``, or ``.try``.

#. **Execution Contexts & Thread Safety**:
   Synchronize shared mutable connection state using ``Sync::Mutex`` (``require "sync/mutex"``) compatible with Crystal 1.21+ multithreaded Execution Contexts.

#. **Line Length**:
   Maximum line length is 120 characters (``Layout/LineLength: MaxLength: 120`` in ``.ameba.yml``).

#. **API Doc Comments**:
   Every public class, struct, module, enum, constant, and method must include Markdown doc comments.
