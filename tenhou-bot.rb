require_relative 'tenhou-client'
require 'nokogiri'
require 'open-uri'

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
    start_pinging
    start_receiving
    if @lobby
      @client.connect_lobby @lobby
    end
  end

  def start_pinging
    if not @ping_thread or not @ping_thread.alive?
      thread = PingThread.new self
      @ping_thread = thread
    end
  end

  def start_receiving
    if not @receive_thread or not @receive_thread.alive?
      thread = ReceiveThread.new self
      @receive_thread = thread
    end
  end

  # def queue_receiving
  #   if not @queue_thread or not @queue_thread.alive?
  #     thread = QueueThread.new self
  #     thread.run
  #     @queue_thread = thread
  #   end
  # end

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
    super{ self.run }
  end

  def run
    while true
      @bot.client.ping
      sleep 5
    end
  rescue Errno::EPIPE
    @bot.client.logger.warn "Tenhou ping failed"
    @bot.start
    sleep 5
  rescue => err
    @bot.client.logger.fatal err
    raise
  end

end