require "./spec_helper"
require "socket"

# Verifies [FUNC-006] / [TECH-006]
describe Crystal::Dbus::Native::PropertiesProxy do
  it "invokes Get, Set, and GetAll on org.freedesktop.DBus.Properties" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    proxy = Crystal::Dbus::Native::PropertiesProxy.new(conn, "org.example.Hostname1", "/org/example/hostname1")

    spawn do
      get_req = Crystal::Dbus::Native::DBusMessage.parse(server)
      get_req.interface.should eq("org.freedesktop.DBus.Properties")
      get_req.member.should eq("Get")
      get_req.decode_body.should eq([
        "org.example.Hostname1".as(Crystal::Dbus::Native::Value),
        "Hostname".as(Crystal::Dbus::Native::Value),
      ])
      get_reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 10_u32, reply_serial: get_req.serial)
      get_reply.encode_body("v", [
        Crystal::Dbus::Native::Variant.new("s", "workstation".as(Crystal::Dbus::Native::Value))
          .as(Crystal::Dbus::Native::Value),
      ])
      get_reply.serialize(server)
      server.flush

      set_req = Crystal::Dbus::Native::DBusMessage.parse(server)
      set_req.member.should eq("Set")
      set_req.signature.should eq("ssv")
      set_reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 11_u32, reply_serial: set_req.serial)
      set_reply.serialize(server)
      server.flush

      all_req = Crystal::Dbus::Native::DBusMessage.parse(server)
      all_req.member.should eq("GetAll")
      all_req.decode_body.should eq(["org.example.Hostname1".as(Crystal::Dbus::Native::Value)])
      dict = Hash(Crystal::Dbus::Native::Value, Crystal::Dbus::Native::Value).new
      dict["Hostname".as(Crystal::Dbus::Native::Value)] = Crystal::Dbus::Native::Variant.new(
        "s", "fedora-host".as(Crystal::Dbus::Native::Value)
      ).as(Crystal::Dbus::Native::Value)
      dict["Chassis".as(Crystal::Dbus::Native::Value)] = Crystal::Dbus::Native::Variant.new(
        "s", "desktop".as(Crystal::Dbus::Native::Value)
      ).as(Crystal::Dbus::Native::Value)
      all_reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 12_u32, reply_serial: all_req.serial)
      all_reply.encode_body("a{sv}", [dict.as(Crystal::Dbus::Native::Value)])
      all_reply.serialize(server)
      server.flush
      server.close
    end

    val = proxy.get("org.example.Hostname1", "Hostname")
    val.signature.should eq("s")
    val.value.should eq("workstation")

    proxy.set(
      "org.example.Hostname1",
      "Hostname",
      Crystal::Dbus::Native::Variant.new("s", "fedora-host".as(Crystal::Dbus::Native::Value))
    )

    all_props = proxy.get_all("org.example.Hostname1")
    all_props["Hostname"].value.should eq("fedora-host")
    all_props["Chassis"].value.should eq("desktop")
    conn.close
  end

  it "decodes PropertiesChanged signal payloads and rejects malformed signals" do
    sig = Crystal::Dbus::Native::DBusMessage.new(
      Crystal::Dbus::Native::Endianness::Little,
      Crystal::Dbus::Native::MessageType::Signal,
      42_u32
    )
    sig.path = "/org/example/hostname1"
    sig.interface = "org.freedesktop.DBus.Properties"
    sig.member = "PropertiesChanged"

    changed_map = Hash(Crystal::Dbus::Native::Value, Crystal::Dbus::Native::Value).new
    changed_map["Hostname".as(Crystal::Dbus::Native::Value)] = Crystal::Dbus::Native::Variant.new(
      "s", "new-host".as(Crystal::Dbus::Native::Value)
    ).as(Crystal::Dbus::Native::Value)
    invalidated_arr = ["KernelRelease".as(Crystal::Dbus::Native::Value)]

    sig.encode_body(
      "sa{sv}as",
      [
        "org.example.Hostname1".as(Crystal::Dbus::Native::Value),
        changed_map.as(Crystal::Dbus::Native::Value),
        invalidated_arr.as(Crystal::Dbus::Native::Value),
      ]
    )

    decoded = Crystal::Dbus::Native::PropertiesProxy.decode_properties_changed(sig)
    decoded[:interface].should eq("org.example.Hostname1")
    decoded[:changed]["Hostname"].value.should eq("new-host")
    decoded[:invalidated].should eq(["KernelRelease"])

    bad_msg = Crystal::Dbus::Native::DBusMessage.method_call(1_u32, "/org/test", "org.test", "Ping")
    expect_raises(Crystal::Dbus::Native::MessageError, "Expected PropertiesChanged signal") do
      Crystal::Dbus::Native::PropertiesProxy.decode_properties_changed(bad_msg)
    end
  end
end

# Verifies [FUNC-006] / [TECH-006]
describe Crystal::Dbus::Native::IntrospectableProxy do
  it "invokes org.freedesktop.DBus.Introspectable.Introspect and returns XML" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    proxy = Crystal::Dbus::Native::IntrospectableProxy.new(conn, "org.freedesktop.DBus", "/org/freedesktop/DBus")
    expected_xml = "<!DOCTYPE node><node><interface name=\"org.freedesktop.DBus\"/></node>"

    spawn do
      req = Crystal::Dbus::Native::DBusMessage.parse(server)
      req.interface.should eq("org.freedesktop.DBus.Introspectable")
      req.member.should eq("Introspect")
      reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 20_u32, reply_serial: req.serial)
      reply.encode_body("s", [expected_xml.as(Crystal::Dbus::Native::Value)])
      reply.serialize(server)
      server.flush
      server.close
    end

    proxy.introspect.should eq(expected_xml)
    conn.close
  end
end
