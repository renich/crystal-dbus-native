===============
Getting Started
===============

Installation
------------

Add ``crystal-dbus-native`` to your project's ``shard.yml``:

.. code-block:: yaml

   dependencies:
     crystal-dbus-native:
       gitlab: renich/crystal-dbus-native
       version: ~> 0.3.1

Install dependencies:

.. code-block:: bash

   shards install

Basic Usage
-----------

Connect to the system or session bus, invoke methods with typed arguments, use ``PropertiesProxy`` and ``IntrospectableProxy``, and subscribe to match-rule signals:

.. code-block:: crystal

   require "crystal-dbus-native"

   conn = Crystal::Dbus::Native::DBusConnection.open_session
   unique_name = conn.start(negotiate_unix_fd: true)

   reply = conn.call(
     destination: "org.freedesktop.DBus",
     path: "/org/freedesktop/DBus",
     interface: "org.freedesktop.DBus",
     member: "GetNameOwner",
     signature: "s",
     values: ["org.freedesktop.DBus".as(Crystal::Dbus::Native::Value)]
   )
   puts reply.decode_body.first

   introspect = Crystal::Dbus::Native::IntrospectableProxy.new(
     conn,
     "org.freedesktop.DBus",
     "/org/freedesktop/DBus"
   )
   puts introspect.introspect

   conn.close

Error Handling
--------------

Catch domain exceptions cleanly:

.. code-block:: crystal

   begin
     Crystal::Dbus::Native::SignatureValidator.validate("a{vs}")
   rescue ex : Crystal::Dbus::Native::SignatureError
     STDERR.puts "Invalid signature: #{ex.message}"
   end
