require 'socket'
require 'logger'

class DisconnectedException < Exception
end

class TenhouClient

  attr_reader :logger

  def initialize
    file = File.new('tenhou-client.log', File::WRONLY | File::APPEND | File::CREAT)
    file.sync = true
    @logger = Logger.new(file)
    @logger.level = Logger::INFO
    @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{severity}] - #{datetime} - #{msg}\n"
    end
  end

  def connect
    @socket = TCPSocket.new '133.242.10.78', 10080
    @logger.info "Connected"
  end

  def receive
    received = @socket.recv 16384
    if received.size == 0
      raise DisconnectedException
    end
    received_list = received.split("\0").compact
    if received_list.empty?
    else
      @logger.info "Received #{received_list}"
    end
    received_list
  end

  def login(login)
    socket_send "<HELO name=\"#{login}\" tid=\"f0\" sx=\"M\" />"
  end

  def send_auth_string(helo_answer)
    auth_string = get_auth(helo_answer)
    socket_send auth_string
  end

  def ping
    socket_send '<Z />'
  end

  def connect_lobby(lobby)
    send_to_chat "%2Flobby%20#{lobby}"
  end

  def send_to_chat(text)
    socket_send "<CHAT text=\"#{text}\" />"
  end

  private

  def socket_send(str)
    @logger.info "Sending: #{str}"
    @socket.sendmsg((str + "\0").encode('ASCII'))
  end

  def get_auth(helo_answer)
    magic = [63006, 9570, 49216, 45888, 9822, 23121, 59830, 51114, 54831, 4189, 580, 5203, 42174, 59972, 55457,
             59009, 59347, 64456, 8673, 52710, 49975, 2006, 62677, 3463, 17754, 5357]
    match_data = /auth="(.*?)-(.*?)"/.match helo_answer
    auth_parts = [match_data[1], match_data[2]]
    loc4 = ('2' + auth_parts[0][2..8]).to_i.modulo (12 - auth_parts[0][7].to_i)
    auth_val_part1 = (magic[loc4 * 2 + 0] ^ auth_parts[1][0..4].hex).to_s(16)
    auth_val_part2 = (magic[loc4 * 2 + 1] ^ auth_parts[1][4..8].hex).to_s(16)
    auth_val = "#{auth_parts[0]}-#{auth_val_part1[2..auth_val_part1.size]}#{auth_val_part2[2..auth_val_part2.size]}"

    "<AUTH val=\"#{auth_val}\"/>"
  end

end