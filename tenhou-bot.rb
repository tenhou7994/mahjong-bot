require_relative 'tenhou-client'
require 'nokogiri'
require 'open-uri'
require 'thread'


class TenhouRunner
  attr_accessor :bot

  def initialize(login, lobby: nil)
    @bot = TenhouBot.new login, lobby: lobby
    @logger = @bot.client.logger
  end

  def start
    @bot.start
    @logger.info 'New Pinging thread starting'
    ping_thread = PingThread.new @bot
    @logger.info 'New Receiving thread starting'
    ReceiveThread.new @bot

  rescue DisconnectedException
    @bot.start
    @logger.warn 'Restarting pinging thread'
    ping_thread.run
  rescue => err
    @logger.fatal err
    raise
  end

  # def queue_receiving
  #   if not @queue_thread or not @queue_thread.alive?
  #     thread = QueueThread.new self
  #     thread.run
  #     @queue_thread = thread
  #   end
  # end

end

class TenhouBot
  attr_reader :client
  attr_accessor :from_chat, :to_chat

  def initialize(login, lobby: nil)
    @client = TenhouClient.new
    @login = login
    @lobby = lobby
  end

  def start
    @client.connect
    @client.login @login

    if @lobby
      @client.connect_lobby @lobby
    end
  end

  def handle_received(received)
    if received =~ /^<HELO/
      @client.send_auth_string(received)
    elsif received =~ /^<CHAT/ and from_chat
      doc = Nokogiri::XML received
      elem = doc.first_element_child
      uname_url = elem.attribute 'uname'
      text_url = elem.attribute 'text'

      uname = uname_url.nil? ? nil : URI::decode(uname_url.value)
      text = text_url.nil? ? nil : URI::decode(text_url.value)
      if uname
        text = "#{uname}: #{text}"
      end
      if text
        from_chat.push text
      end
    end
  rescue => err
    @client.logger.error err
  end
end

class ReceiveThread < Thread
  def initialize(bot)
    @bot = bot
    super{ self.run }
  end

  def run
    while true
      @bot.client.receive.each do |recieved|
        @bot.handle_received recieved
      end
    end
  rescue => err
    @bot.client.logger.error err
  end

end

class PingThread < Thread
  def initialize(bot)
    @bot = bot
    self.abort_on_exception = true
    super{ self.run }
  end

  def run
    while true
      @bot.client.ping
      sleep 5
    end
  rescue Errno::EPIPE
    @bot.client.logger.warn "Tenhou ping failed"
    raise DisconnectedException
  rescue => err
    @bot.client.logger.fatal err
    raise
  end
end

# class QueueThread < Thread
#   def initialize(bot)
#     @bot = bot
#     super{ self.run }
#   end
#
#   def run
#     while true
#       command = @bot.to_chat.pop
#       @bot.client.send_to_chat command
#       sleep 1
#     end
#   rescue => err
#     @bot.client.logger.error err
#   end
# end
