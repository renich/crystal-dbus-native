require "socket"

module Crystal::Dbus::Native
  class DBusConnection
    def initialize(@client : UNIXSocket)
    end

    def start
      # Start handling connection if necessary
      true
    end

    def close
      @client.close unless @client.closed?
    end
  end
end
