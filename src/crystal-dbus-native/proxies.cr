module Crystal::Dbus::Native
  # Client proxy for the standard `org.freedesktop.DBus.Properties` interface.
  class PropertiesProxy
    # Standard D-Bus interface name for object properties.
    INTERFACE = "org.freedesktop.DBus.Properties"

    # Returns the underlying `DBusConnection`.
    getter connection : DBusConnection

    # Returns the target bus destination name.
    getter destination : String

    # Returns the target D-Bus object path.
    getter path : String

    # Creates a new `PropertiesProxy` bound to `connection`, `destination`, and `path`.
    def initialize(@connection : DBusConnection, @destination : String, @path : String) : Nil
    end

    # Invokes `org.freedesktop.DBus.Properties.Get` and returns the property `Variant`.
    def get(interface : String, property : String) : Variant
      reply = @connection.call(
        destination: @destination,
        path: @path,
        interface: INTERFACE,
        member: "Get",
        signature: "ss",
        values: [interface.as(Value), property.as(Value)]
      )
      first = reply.decode_body.first?
      return first if first.is_a?(Variant)
      raise MessageError.new("Expected Variant reply payload from Properties.Get")
    end

    # Invokes `org.freedesktop.DBus.Properties.Set` for `interface` and `property` with `value`.
    def set(interface : String, property : String, value : Variant) : Nil
      @connection.call(
        destination: @destination,
        path: @path,
        interface: INTERFACE,
        member: "Set",
        signature: "ssv",
        values: [interface.as(Value), property.as(Value), value.as(Value)]
      )
    end

    # Invokes `org.freedesktop.DBus.Properties.GetAll` and decodes `a{sv}` into `Hash(String, Variant)`.
    def get_all(interface : String) : Hash(String, Variant)
      reply = @connection.call(
        destination: @destination,
        path: @path,
        interface: INTERFACE,
        member: "GetAll",
        signature: "s",
        values: [interface.as(Value)]
      )
      first = reply.decode_body.first?
      return extract_variant_dict(first) if first.is_a?(Hash(Value, Value))
      raise MessageError.new("Expected a{sv} dictionary reply payload from Properties.GetAll")
    end

    # Decodes an `org.freedesktop.DBus.Properties.PropertiesChanged` (`sa{sv}as`) signal message.
    def self.decode_properties_changed(
      msg : DBusMessage,
    ) : NamedTuple(interface: String, changed: Hash(String, Variant), invalidated: Array(String))
      unless msg.message_type == MessageType::Signal && msg.member == "PropertiesChanged"
        raise MessageError.new("Expected PropertiesChanged signal message")
      end

      body = msg.decode_body
      raise MessageError.new("Malformed PropertiesChanged payload") unless body.size == 3
      iface = body[0]
      changed_raw = body[1]
      invalidated_raw = body[2]
      unless iface.is_a?(String) && changed_raw.is_a?(Hash(Value, Value)) && invalidated_raw.is_a?(Array(Value))
        raise MessageError.new("Invalid field types in PropertiesChanged signal")
      end

      {
        interface:   iface,
        changed:     extract_variant_dict(changed_raw),
        invalidated: extract_string_array(invalidated_raw),
      }
    end

    protected def self.extract_variant_dict(raw : Hash(Value, Value)) : Hash(String, Variant)
      result = Hash(String, Variant).new
      raw.each do |key, val|
        unless key.is_a?(String) && val.is_a?(Variant)
          raise MessageError.new("Expected String key and Variant value in property dictionary")
        end
        result[key] = val
      end
      result
    end

    protected def self.extract_string_array(raw : Array(Value)) : Array(String)
      raw.map do |item|
        raise MessageError.new("Expected String element in invalidated property array") unless item.is_a?(String)
        item
      end
    end

    private def extract_variant_dict(raw : Hash(Value, Value)) : Hash(String, Variant)
      self.class.extract_variant_dict(raw)
    end
  end

  # Client proxy for the standard `org.freedesktop.DBus.Introspectable` interface.
  class IntrospectableProxy
    # Standard D-Bus interface name for XML introspection.
    INTERFACE = "org.freedesktop.DBus.Introspectable"

    # Returns the underlying `DBusConnection`.
    getter connection : DBusConnection

    # Returns the target bus destination name.
    getter destination : String

    # Returns the target D-Bus object path.
    getter path : String

    # Creates a new `IntrospectableProxy` bound to `connection`, `destination`, and `path`.
    def initialize(@connection : DBusConnection, @destination : String, @path : String) : Nil
    end

    # Invokes `org.freedesktop.DBus.Introspectable.Introspect` and returns the XML document string.
    def introspect : String
      reply = @connection.call(
        destination: @destination,
        path: @path,
        interface: INTERFACE,
        member: "Introspect"
      )
      first = reply.decode_body.first?
      return first if first.is_a?(String)
      raise MessageError.new("Expected XML String reply payload from Introspectable.Introspect")
    end
  end
end
