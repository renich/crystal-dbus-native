=====================
Architecture Overview
=====================

Requirement Mapping
-------------------

Fulfills ``[FUNC-001]``, ``[FUNC-002]``, ``[FUNC-003]``, ``[FUNC-004]``, ``[FUNC-005]``, and ``[FUNC-006]``.

Library Layout & Namespaces
---------------------------

The library source is organized under the ``Crystal::Dbus::Native`` namespace:

* **src/crystal-dbus-native.cr**: Shard entrypoint and ``VERSION`` constant.
* **src/crystal-dbus-native/errors.cr**: Domain exception hierarchy (`DBusError`, `AuthError`, `SignatureError`, `MessageError`, `ConnectionClosedError`).
* **src/crystal-dbus-native/variant.cr**: Value-semantic structs (`ObjectPath`, `Signature`, `UnixFD`, `StructValue`, `Variant`) and recursive ``Value`` union alias.
* **src/crystal-dbus-native/signature_validator.cr**: Recursive D-Bus signature validator and single-type splitter (`SignatureValidator`).
* **src/crystal-dbus-native/header_codec.cr**: Header field array (``a(yv)``) parser and serializer (`HeaderCodec` and `HeaderField`).
* **src/crystal-dbus-native/body_codec.cr**: General-purpose D-Bus wire body marshaler and unmarshaler (`BodyCodec`).
* **src/crystal-dbus-native/dbus_message.cr**: Framed D-Bus wire message representation (`DBusMessage`, `Endianness`, `MessageType`).
* **src/crystal-dbus-native/sasl_authenticator.cr**: Client-side SASL ``EXTERNAL`` and ``NEGOTIATE_UNIX_FD`` handshake (`SASLAuthenticator`).
* **src/crystal-dbus-native/secure_fd_passer.cr**: ``SCM_RIGHTS`` ancillary file descriptor transport (`SecureFDPasser`).
* **src/crystal-dbus-native/dbus_connection.cr**: UNIX domain socket connection, RPC ``call``, FD passing, and signal queue (`DBusConnection`).

Wire Framing & Body Marshaling
------------------------------

Immutable D-Bus payload wrappers (`ObjectPath`, `Signature`, `UnixFD`, `StructValue`, `Variant`) are defined as Crystal ``struct`` types. ``BodyCodec`` encodes into a single ``IO::Memory`` stream so every nested container and element alignment boundary (1, 2, 4, or 8 bytes) is computed relative to the message body origin, patching 4-byte array lengths in place and advancing to 8-byte boundaries even for empty arrays of 8-byte elements such as ``a{sv}`` or ``a(ii)``.
