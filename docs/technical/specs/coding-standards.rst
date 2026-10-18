================
Coding Standards
================

Requirement Mapping
-------------------

Fulfills ``[FUNC-001]``, ``[FUNC-002]``, ``[FUNC-003]``, ``[FUNC-004]``, ``[FUNC-005]``, and ``[FUNC-006]``.

Core Directives
---------------

#. **Strict Static Analysis**:
   Full default rule sets for Ameba and Flaw are enabled. Global rule suppression in ``.ameba.yml`` and inline ``# ameba:disable`` or ``# flaw:disable`` annotations are strictly prohibited.

#. **Modularity & Complexity Limits**:
   Every Crystal source and spec file must remain at or under 220 lines, every method at or under 25 lines, and cyclomatic complexity at or under 10.

#. **Defensive Nil Handling & Explicit Types**:
   Never call ``.not_nil!``. All method parameters and return types must carry explicit type annotations, using type narrowing with ``if``, ``case``, or ``.try``.

#. **Line Length**:
   Maximum line length is 120 characters (``Layout/LineLength: MaxLength: 120`` in ``.ameba.yml``).

#. **API Doc Comments**:
   Every public class, struct, module, enum, constant, and method must include Markdown doc comments.
