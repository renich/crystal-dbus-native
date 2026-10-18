============
Phase 1: MVP
============

Timeline & Objectives
---------------------

Deliver the core zero-dependency D-Bus wire framing, SASL ``EXTERNAL`` authentication, signature validator, and ``SCM_RIGHTS`` file descriptor passing primitives.

Milestones & Deliverables
-------------------------

* **Milestone 1.1: Wire Framing & Transport** (Fulfills ``[FUNC-001]``, ``[FUNC-002]``, ``[FUNC-004]``, ``[FUNC-005]``):

  - [x] 16-byte fixed header and ``a(yv)`` header field serialization (`DBusMessage`).
  - [x] SASL ``EXTERNAL`` and ``NEGOTIATE_UNIX_FD`` handshake (`SASLAuthenticator`).
  - [x] ``SCM_RIGHTS`` descriptor passing with ``MSG_CMSG_CLOEXEC`` (`SecureFDPasser`).
  - [x] Recursive D-Bus signature validator (`SignatureValidator`).
