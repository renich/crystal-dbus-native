============
Threat Model
============

Requirement Mapping
-------------------

Fulfills ``[FUNC-001]``, ``[FUNC-002]``, ``[FUNC-003]``, ``[FUNC-004]``, and ``[FUNC-005]``.

Security Controls Summary
-------------------------

.. list-table::
   :header-rows: 1
   :widths: 15 40 45

   * - Control ID
     - Vulnerability Vector
     - Mitigation Implemented
   * - SEC-01
     - Integer underflow or out-of-bounds read in ``cmsghdr`` parsing
     - Validate ``offset + hdr_len <= total_len`` and ``cmsg_len >= hdr_len`` in ``UInt64`` before subtraction
   * - SEC-02
     - Integer overflow in message payload allocation
     - Check ``body_len.to_u64 + fields_len.to_u64 > max_size.to_u64`` before allocating ``Bytes``
   * - SEC-03
     - Unbounded SASL line allocation
     - Enforce ``MAX_LINE_LENGTH = 4096`` in ``SASLAuthenticator.read_response``
   * - SEC-04
     - File descriptor leakage on ``execve`` or ``MSG_CTRUNC`` truncation
     - Pass ``MSG_CMSG_CLOEXEC`` to ``recvmsg`` and close all extracted FDs on ``MSG_CTRUNC`` or parse error
   * - SEC-05
     - Thread race or zero wrap-around in message serials and signal queue
     - Synchronize ``next_serial`` and ``@signal_queue`` with ``Sync::Mutex`` and skip ``0_u32``
   * - SEC-06
     - Unbounded container recursion in type signatures
     - Enforce ``MAX_LENGTH = 255`` and independent ``MAX_DEPTH = 32`` limits for arrays and structs
