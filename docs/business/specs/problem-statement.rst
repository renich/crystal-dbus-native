=================
Problem Statement
=================

Context
-------

Interacting with Linux system and session D-Bus services in Crystal traditionally requires binding against C libraries such as ``libdbus-1`` or ``libsystemd``. External C bindings introduce dynamic linking dependencies, complicate static compilation on Alpine/musl targets, obscure non-blocking Crystal fiber event loop integration, and make low-level ``SCM_RIGHTS`` file descriptor lifetime management error-prone.

Solution
--------

``crystal-dbus-native`` provides a pure, zero-dependency Crystal implementation of the D-Bus wire protocol v1, SASL ``EXTERNAL`` authentication, ``NEGOTIATE_UNIX_FD`` negotiation, general-purpose body marshaling and unmarshaling, ``SCM_RIGHTS`` ancillary file descriptor passing with atomic ``MSG_CMSG_CLOEXEC`` protection, and a phased path to typed standard interface proxies and multiplexed concurrent fiber RPC.
