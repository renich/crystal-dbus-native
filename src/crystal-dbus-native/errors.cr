module Crystal::Dbus::Native
  class DBusError < Exception; end

  class AuthError < DBusError; end

  class SignatureError < DBusError; end

  class MessageError < DBusError; end

  class ConnectionClosedError < DBusError; end
end
