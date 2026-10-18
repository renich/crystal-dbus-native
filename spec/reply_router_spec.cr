require "./spec_helper"
require "socket"

# Verifies [FUNC-007] / [TECH-005], [TECH-007]
describe Crystal::Dbus::Native::ReplyRouter do
  it "demultiplexes out-of-order replies across concurrent fibers without head-of-line blocking" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)

    spawn do
      requests = Array(Crystal::Dbus::Native::DBusMessage).new
      3.times { requests << Crystal::Dbus::Native::DBusMessage.parse(server) }

      requests.reverse_each do |req|
        reply = Crystal::Dbus::Native::DBusMessage.method_return(
          serial: req.serial + 100_u32,
          reply_serial: req.serial
        )
        arg = req.decode_body.first.as(String)
        reply.encode_body("s", ["reply:#{arg}".as(Crystal::Dbus::Native::Value)])
        reply.serialize(server)
      end
      server.flush
      server.close
    end

    results = Channel(Tuple(Int32, String)).new(3)
    3.times do |idx|
      spawn do
        res = conn.call(
          destination: "org.example.Service",
          path: "/org/example/Object",
          interface: "org.example.Interface",
          member: "Echo",
          signature: "s",
          values: ["call-#{idx}".as(Crystal::Dbus::Native::Value)]
        )
        results.send({idx, res.decode_body.first.as(String)})
      end
    end

    collected = Hash(Int32, String).new
    3.times do
      idx, payload = results.receive
      collected[idx] = payload
    end

    collected[0].should eq("reply:call-0")
    collected[1].should eq("reply:call-1")
    collected[2].should eq("reply:call-2")
    conn.pending_reply_count.should eq(0)
    conn.close
  end

  it "cleans up pending reply channels and wakes blocked callers with ConnectionClosedError on close" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    err_ch = Channel(Exception?).new(1)

    spawn do
      _req = Crystal::Dbus::Native::DBusMessage.parse(server)
      server.close
    end

    spawn do
      conn.call("org.example.Svc", "/org/example/Obj", "org.example.Iface", "Hang")
      err_ch.send(nil)
    rescue ex
      err_ch.send(ex)
    end

    err = err_ch.receive
    err.should be_a(Crystal::Dbus::Native::ConnectionClosedError)
    conn.pending_reply_count.should eq(0)
    conn.close
  end

  it "subscribes to match rules via AddMatch, filters signals, and unsubscribes via RemoveMatch" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    rule = "type='signal',interface='org.example.Events',member='Triggered',path='/org/example/Node',sender=':1.50'"

    spawn do
      add_req = Crystal::Dbus::Native::DBusMessage.parse(server)
      add_req.member.should eq("AddMatch")
      add_req.decode_body.should eq([rule.as(Crystal::Dbus::Native::Value)])
      add_reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 10_u32, reply_serial: add_req.serial)
      add_reply.serialize(server)
      server.flush

      non_matching = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::Signal,
        11_u32
      )
      non_matching.path = "/org/example/Other"
      non_matching.interface = "org.example.Events"
      non_matching.member = "Triggered"
      non_matching.sender = ":1.50"
      non_matching.serialize(server)

      matching = Crystal::Dbus::Native::DBusMessage.new(
        Crystal::Dbus::Native::Endianness::Little,
        Crystal::Dbus::Native::MessageType::Signal,
        12_u32
      )
      matching.path = "/org/example/Node"
      matching.interface = "org.example.Events"
      matching.member = "Triggered"
      matching.sender = ":1.50"
      matching.encode_body("s", ["matched-event".as(Crystal::Dbus::Native::Value)])
      matching.serialize(server)
      server.flush

      rem_req = Crystal::Dbus::Native::DBusMessage.parse(server)
      rem_req.member.should eq("RemoveMatch")
      rem_req.decode_body.should eq([rule.as(Crystal::Dbus::Native::Value)])
      rem_reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 13_u32, reply_serial: rem_req.serial)
      rem_reply.serialize(server)
      server.flush
      server.close
    end

    sub_ch = conn.subscribe_signal(rule, send_bus_match: true)
    sig = sub_ch.receive
    sig.decode_body.should eq(["matched-event".as(Crystal::Dbus::Native::Value)])

    conn.unsubscribe_signal(rule, sub_ch, send_bus_match: true)
    sub_ch.closed?.should be_true
    conn.close
  end

  it "never blocks the reader fiber when a subscriber channel reaches its 64-message capacity" do
    client, server = UNIXSocket.pair(Socket::Type::STREAM)
    conn = Crystal::Dbus::Native::DBusConnection.new(client)
    rule = "type='signal',interface='org.example.Flood',path_namespace='/org/example'"
    sub_ch = conn.subscribe_signal(rule, send_bus_match: false)

    spawn do
      req = Crystal::Dbus::Native::DBusMessage.parse(server)
      70.times do |idx|
        sig = Crystal::Dbus::Native::DBusMessage.new(
          Crystal::Dbus::Native::Endianness::Little,
          Crystal::Dbus::Native::MessageType::Signal,
          (100 + idx).to_u32
        )
        sig.path = "/org/example/sub/item"
        sig.interface = "org.example.Flood"
        sig.member = "Tick"
        sig.serialize(server)
      end

      reply = Crystal::Dbus::Native::DBusMessage.method_return(serial: 200_u32, reply_serial: req.serial)
      reply.encode_body("s", ["pong".as(Crystal::Dbus::Native::Value)])
      reply.serialize(server)
      server.flush
      server.close
    end

    reply = conn.call("org.example.Flood", "/org/example", "org.example.Flood", "Ping")
    reply.decode_body.should eq(["pong".as(Crystal::Dbus::Native::Value)])

    received = 0
    64.times do
      sub_ch.receive
      received += 1
    end
    received.should eq(64)

    polled = 0
    while conn.poll_signal
      polled += 1
    end
    polled.should eq(64)

    expect_raises(Crystal::Dbus::Native::DBusError, "Invalid D-Bus match rule") do
      conn.subscribe_signal("invalid_token_without_equals", send_bus_match: false)
    end
    conn.close
  end
end
