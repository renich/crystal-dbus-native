Security Considerations
=======================

Security is a primary focus for ``crystal-dbus-native``. The library implements robust mitigations against common protocol-level attacks.

Integer Safety
--------------

The D-Bus protocol relies on length prefixes, making integer overflows a critical vulnerability vector. The implementation uses strict overflow-safe arithmetic.

Checks are performed *before* operations:

.. code-block:: crystal

   # Check BEFORE subtraction
   if cmsg_len < CMSG_HDR_SIZE
     raise "Invalid cmsg_len"
   end
   fd_data_len = cmsg_len - CMSG_HDR_SIZE

   # Check BEFORE addition
   if body_length > max_size - HEADER_SIZE
     raise "Message too large"
   end

Authentication Bypass Mitigation
--------------------------------

To verify peer credentials securely, the implementation relies on ``SCM_CREDENTIALS`` via Linux domain sockets.

* The ``SO_PASSCRED`` socket option is enabled.
* Credentials are received securely via ``recvmsg``.
* The system verifies that the UID matches the claimed identity, preventing user-space spoofing attempts.
