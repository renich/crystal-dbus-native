module Crystal::Dbus::Native
  # Base exception class for all D-Bus protocol and transport errors.
  class DBusError < Exception; end

  # Raised when SASL authentication or feature negotiation fails.
  class AuthError < DBusError; end

  # Raised when a D-Bus type signature violates structural or nesting rules.
  class SignatureError < DBusError; end

  # Raised when a D-Bus wire message is malformed or violates protocol constraints.
  class MessageError < DBusError; end

  # Raised when the underlying transport socket closes unexpectedly.
  class ConnectionClosedError < DBusError; end
end
