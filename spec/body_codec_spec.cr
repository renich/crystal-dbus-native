require "./spec_helper"

describe Crystal::Dbus::Native::BodyCodec do
  it "round-trips all basic D-Bus primitive types in LittleEndian" do
    sig = "ybnqiuxtdsohg"
    values = [
      0x7f_u8.as(Crystal::Dbus::Native::Value),
      true.as(Crystal::Dbus::Native::Value),
      -1234_i16.as(Crystal::Dbus::Native::Value),
      5678_u16.as(Crystal::Dbus::Native::Value),
      -100_000_i32.as(Crystal::Dbus::Native::Value),
      200_000_u32.as(Crystal::Dbus::Native::Value),
      -9_000_000_000_i64.as(Crystal::Dbus::Native::Value),
      18_000_000_000_u64.as(Crystal::Dbus::Native::Value),
      3.141_592_653_589_793_f64.as(Crystal::Dbus::Native::Value),
      "hello dbus".as(Crystal::Dbus::Native::Value),
      Crystal::Dbus::Native::ObjectPath.new("/org/freedesktop/DBus").as(Crystal::Dbus::Native::Value),
      Crystal::Dbus::Native::UnixFD.new(0_u32).as(Crystal::Dbus::Native::Value),
      Crystal::Dbus::Native::Signature.new("a{sv}(ii)").as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value

    encoded = Crystal::Dbus::Native::BodyCodec.encode(sig, values)
    decoded = Crystal::Dbus::Native::BodyCodec.decode(sig, encoded)
    decoded.should eq(values)
  end

  it "round-trips nested structs (su(ii)) and arrays in BigEndian" do
    sig = "(su(ii))au"
    inner = Crystal::Dbus::Native::StructValue.new([
      -42_i32.as(Crystal::Dbus::Native::Value),
      99_i32.as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value)
    outer = Crystal::Dbus::Native::StructValue.new([
      "secret-label".as(Crystal::Dbus::Native::Value),
      777_u32.as(Crystal::Dbus::Native::Value),
      inner.as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value)
    arr = [
      10_u32.as(Crystal::Dbus::Native::Value),
      20_u32.as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value
    values = [
      outer.as(Crystal::Dbus::Native::Value),
      arr.as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value

    encoded = Crystal::Dbus::Native::BodyCodec.encode(sig, values, Crystal::Dbus::Native::Endianness::Big)
    decoded = Crystal::Dbus::Native::BodyCodec.decode(sig, encoded, Crystal::Dbus::Native::Endianness::Big)
    decoded.should eq(values)
  end

  it "round-trips dictionaries a{sv} with Variant values" do
    sig = "a{sv}"
    dict = Hash(Crystal::Dbus::Native::Value, Crystal::Dbus::Native::Value).new
    dict["org.freedesktop.Secret.Item.Label".as(Crystal::Dbus::Native::Value)] =
      Crystal::Dbus::Native::Variant.new("s", "API Token").as(Crystal::Dbus::Native::Value)
    dict["org.freedesktop.Secret.Item.Locked".as(Crystal::Dbus::Native::Value)] =
      Crystal::Dbus::Native::Variant.new("b", false).as(Crystal::Dbus::Native::Value)

    values = [dict.as(Crystal::Dbus::Native::Value)] of Crystal::Dbus::Native::Value
    encoded = Crystal::Dbus::Native::BodyCodec.encode(sig, values)
    decoded = Crystal::Dbus::Native::BodyCodec.decode(sig, encoded)
    decoded.should eq(values)
  end

  it "advances to 8-byte alignment for empty arrays of 8-byte elements a{sv} and a(ii)" do
    empty_dict = Hash(Crystal::Dbus::Native::Value, Crystal::Dbus::Native::Value).new
    empty_structs = Array(Crystal::Dbus::Native::Value).new
    values = [
      empty_dict.as(Crystal::Dbus::Native::Value),
      empty_structs.as(Crystal::Dbus::Native::Value),
      42_u32.as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value

    encoded = Crystal::Dbus::Native::BodyCodec.encode("a{sv}a(ii)u", values)
    encoded.size.should eq(20)
    decoded = Crystal::Dbus::Native::BodyCodec.decode("a{sv}a(ii)u", encoded)
    decoded.should eq(values)
  end

  it "encodes and decodes message bodies via DBusMessage#encode_body and #decode_body" do
    msg = Crystal::Dbus::Native::DBusMessage.method_call(
      serial: 7_u32,
      path: "/org/freedesktop/secrets",
      interface: "org.freedesktop.Secret.Service",
      member: "OpenSession"
    )
    input = [
      "plain".as(Crystal::Dbus::Native::Value),
      Crystal::Dbus::Native::Variant.new("s", "").as(Crystal::Dbus::Native::Value),
    ] of Crystal::Dbus::Native::Value

    msg.encode_body("sv", input)
    msg.signature.should eq("sv")
    msg.decode_body.should eq(input)
  end

  it "rejects mismatched value counts or invalid object paths" do
    expect_raises(Crystal::Dbus::Native::MessageError, "Value count") do
      Crystal::Dbus::Native::BodyCodec.encode("su", ["only-one".as(Crystal::Dbus::Native::Value)])
    end

    expect_raises(Crystal::Dbus::Native::MessageError, "Object path must start with '/'") do
      Crystal::Dbus::Native::BodyCodec.encode(
        "o",
        [Crystal::Dbus::Native::ObjectPath.new("relative/path").as(Crystal::Dbus::Native::Value)]
      )
    end
  end
end
