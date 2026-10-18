require "sync/mutex"

module Crystal::Dbus::Native
  # Demultiplexes inbound D-Bus method replies across concurrent calling fibers
  # and routes `MessageType::Signal` frames to bounded match-rule subscriber channels.
  class ReplyRouter
    # Capacity of per-call buffered reply channels.
    REPLY_CHANNEL_CAPACITY = 1

    # Capacity of bounded per-subscriber signal channels.
    SIGNAL_CHANNEL_CAPACITY = 64

    @mutex : Sync::Mutex
    @pending_replies : Hash(UInt32, Channel(DBusMessage))
    @subscriptions : Hash(String, Array(Channel(DBusMessage)))
    @signal_queue : Deque(DBusMessage)
    @closed : Bool

    # Initializes an empty `ReplyRouter`.
    def initialize : Nil
      @mutex = Sync::Mutex.new
      @pending_replies = Hash(UInt32, Channel(DBusMessage)).new
      @subscriptions = Hash(String, Array(Channel(DBusMessage))).new
      @signal_queue = Deque(DBusMessage).new
      @closed = false
    end

    # Returns the number of currently registered pending reply channels.
    def pending_reply_count : Int32
      @mutex.synchronize { @pending_replies.size }
    end

    # Registers and returns a buffered `Channel(DBusMessage).new(1)` for `serial`.
    def register_reply(serial : UInt32) : Channel(DBusMessage)
      @mutex.synchronize do
        raise ConnectionClosedError.new("Connection closed") if @closed
        channel = Channel(DBusMessage).new(REPLY_CHANNEL_CAPACITY)
        @pending_replies[serial] = channel
        channel
      end
    end

    # Removes `serial` from the pending reply table and closes its channel if still present.
    def unregister_reply(serial : UInt32) : Nil
      channel = @mutex.synchronize { @pending_replies.delete(serial) }
      return unless channel
      channel.close unless channel.closed?
    end

    # Pops and returns the next queued signal message, or `nil` if the queue is empty.
    def poll_signal : DBusMessage?
      @mutex.synchronize { @signal_queue.shift? }
    end

    # Validates `match_rule`, registers a bounded `Channel(DBusMessage).new(64)`, and returns it.
    def subscribe(match_rule : String) : Channel(DBusMessage)
      validate_match_rule(match_rule)
      @mutex.synchronize do
        raise ConnectionClosedError.new("Connection closed") if @closed
        channel = Channel(DBusMessage).new(SIGNAL_CHANNEL_CAPACITY)
        list = @subscriptions[match_rule]? || begin
          new_list = Array(Channel(DBusMessage)).new
          @subscriptions[match_rule] = new_list
          new_list
        end
        list << channel
        channel
      end
    end

    # Removes `channel` from `match_rule` subscriptions and closes `channel`.
    def unsubscribe(match_rule : String, channel : Channel(DBusMessage)) : Nil
      @mutex.synchronize do
        if list = @subscriptions[match_rule]?
          list.delete(channel)
          @subscriptions.delete(match_rule) if list.empty?
        end
      end
      channel.close unless channel.closed?
    end

    # Routes an inbound `DBusMessage` to its pending reply channel or matching signal subscribers.
    def dispatch(msg : DBusMessage) : Nil
      if msg.message_type == MessageType::Signal
        dispatch_signal(msg)
        return
      end

      return unless r_serial = msg.reply_serial
      channel = @mutex.synchronize { @pending_replies.delete(r_serial) }
      deliver_non_blocking(channel, msg) if channel
    end

    # Closes all pending reply channels and signal subscription channels.
    def close_all : Nil
      channels = Array(Channel(DBusMessage)).new
      @mutex.synchronize do
        @closed = true
        @pending_replies.each_value { |channel| channels << channel }
        @pending_replies.clear
        @subscriptions.each_value do |list|
          list.each { |channel| channels << channel }
        end
        @subscriptions.clear
      end
      channels.each { |channel| channel.close unless channel.closed? }
    end

    # Validates that `match_rule` consists of well-formed `key=value` tokens.
    def validate_match_rule(match_rule : String) : Nil
      return if match_rule.empty?
      match_rule.split(',').each do |raw_token|
        token = raw_token.strip
        next if token.empty?
        key, sep, _val = token.partition('=')
        if sep.empty? || key.strip.empty?
          raise DBusError.new("Invalid D-Bus match rule token: #{token}")
        end
      end
    end

    private def dispatch_signal(msg : DBusMessage) : Nil
      matching_channels = Array(Channel(DBusMessage)).new
      @mutex.synchronize do
        @signal_queue.shift? if @signal_queue.size >= SIGNAL_CHANNEL_CAPACITY
        @signal_queue << msg
        @subscriptions.each do |rule, list|
          next unless rule_matches?(rule, msg)
          list.each { |channel| matching_channels << channel }
        end
      end
      matching_channels.each { |channel| deliver_non_blocking(channel, msg) }
    end

    private def deliver_non_blocking(channel : Channel(DBusMessage), msg : DBusMessage) : Nil
      return if channel.closed?
      select
      when channel.send(msg)
      else
      end
    rescue Channel::ClosedError
    end

    private def rule_matches?(rule : String, msg : DBusMessage) : Bool
      return true if rule.empty?
      rule.split(',').all? do |raw_token|
        token = raw_token.strip
        next true if token.empty?
        key, _sep, raw_val = token.partition('=')
        val = raw_val.strip.lstrip('\'').rstrip('\'')
        matches_criterion?(msg, key.strip, val)
      end
    end

    private def matches_criterion?(msg : DBusMessage, key : String, val : String) : Bool
      case key
      when "type"           then val == "signal"
      when "interface"      then msg.interface == val
      when "member"         then msg.member == val
      when "path"           then msg.path == val
      when "path_namespace" then matches_namespace?(msg.path, val)
      when "sender"         then msg.sender == val
      when "destination"    then msg.destination == val
      else                       false
      end
    end

    private def matches_namespace?(path : String?, namespace : String) : Bool
      return false unless path
      path == namespace || path.starts_with?("#{namespace}/")
    end
  end
end
