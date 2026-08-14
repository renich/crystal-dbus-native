module Crystal::Dbus::Native
  VERSION = "0.1.1"
end

require "./crystal-dbus-native/errors"
require "./crystal-dbus-native/dbus_connection"
require "./crystal-dbus-native/dbus_message"
require "./crystal-dbus-native/sasl_authenticator"
require "./crystal-dbus-native/secure_fd_passer"
require "./crystal-dbus-native/signature_validator"
