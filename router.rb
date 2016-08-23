# encoding: utf-8

class Router
  attr_accessor :default_chat_id
  attr_reader :logger

  def initialize(db)
    @db = db

    file = File.new('tenhou-router.log', File::WRONLY | File::APPEND | File::CREAT)
    file.sync = true
    @logger = Logger.new(file)
    @logger.level = Logger::INFO
    @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{severity}] - #{datetime} - #{msg}\n"
    end
  end

  def route_message(message)
    @chat = message['chat']
    @user = message['from']
    @message_text = message['text']
    case @message_text
      when /\/hlon\s?/
        set_highlights_on

      when /\/hloff\s?.*/
        set_highlights_off

      when /\/mahjong\s?.*/
        call_to_arms

      when /\/me\s.*/
        bind_name

      when /^\/stat3\s?$/
        count_self_stat 3

      when /\/stat3\s(\d{1,4}|\w*)(\s.*\s?)?/
        count_hard_stat $1, $2, 3

      when /^\/stat\s?$/
        count_self_stat 4

      when /\/stat\s(\d{1,4}|\w*)(\s.*\s?)?/
        count_hard_stat $1, $2, 4

      when /\/whois\s.*/
        say_who

      when /\/set_sch\s\d?\s?\d{1,2}:\d{1,2}\s?-\s?\d{1,2}:\d{1,2}/
        set_user_sch

      when /\/rm_sch\s\d/
        rm_user_sch

      when /\/my_sch\s?.*/
        send_user_sch

      when /\/help\s?.*/
        send_help

      when /\/list/
        if @user['id'] == 53783180
          get_users_from_db
        end
      else
    end
  rescue => err
    @logger.error err
    raise
  end

  def route_queue(text)
    case text
      when /^#(START|END)/
        send_message text, chat: default_chat_id
      else
    end
  end

  private

  def in_interval?(chat_id)
    sch = @db.get_schedule chat_id: chat_id, dow: Time.now.wday
    if sch.size == 0
      sch = @db.get_schedule chat_id: chat_id
      if sch.size == 0
        true
      else
        time1 = sch[0][0]
        time2 = sch[0][1]
        Time.now.between?(Time.parse(time1), time2 > time1 ? Time.parse(time2) : Time.parse(time2) + 86400)
      end
    else
      time1 = sch[0][0]
      time2 = sch[0][1]
      Time.now.between?(Time.parse(time1), time2 > time1 ? Time.parse(time2) : Time.parse(time2) + 86400)
    end
  end

  def set_highlights_on
    if @user['username'].nil?
      text = 'Please set your username in telegram profile.'
      send_message text
    else
      if @db.get_users(c_id: @user['id']).size > 0
        @db.update_user @user['id'], username: @user['username'], hl_s: 1
      else
        @db.add_user @user['id'], username: @user['username']
      end
    end
  end

  def set_highlights_off
    if @user['username'].nil?
      text = 'You have no username, highlights disabled by default.'
      send_message text
    else
      if @db.get_users(c_id: @user['id']).size > 0
        @db.update_user @user['id'], username: @user['username'], hl_s: 0
      else
        @db.add_user @user['id'], @user['username'], hl_s: 0
      end
    end
  end

  def call_to_arms
    text = "@#{@user['username']} призывает нажать кнопку в лобби tenhou.net/0/?L7994 (tenhou.net/3/beta.html?L7994) \n"
    @db.get_users(hl_s: 1).each do |row|
      if in_interval? row[1]
        text += "@#{row[0]} | "
      end
    end
    send_message text
  end

  def bind_name
    name = @message_text.gsub(/\/me\s/, '')
    if @db.get_users(c_id: @user['id']).size > 0
      @db.update_user @user['id'], username: @user['username'], t_id: name
    else
      if @user['username'].nil?
        @db.add_user @user['id'], username: @user['username'], t_id: name, hl_s: 0
      else
        @db.add_user @user['id'], username: @user['username'], t_id: name
      end
    end
    text = "Никнейм #{name} на tenhou ассоциирован с Вами. Теперь Вы можете воспользоваться командой /stat {lobby_number}"
    send_message text
  end

  def count_self_stat(man)
    user = @db.get_users(c_id: @user['id'])
    if user.size > 0
      player = user[0][1]
      text = get_stat player, man
    else
      text = 'You have no tenhou name binded to you. Use /me {tenhou_name} command first.'
    end
    send_message text
  end

  def count_hard_stat(lobby_string, player, man)
    if player.nil? or player.gsub!(/^\s/, '').gsub!(/\s$/, '') == ''
      u_name = @db.get_users(c_id: @user['id'])
      u_name.size > 0 ? player = u_name[0][1] : player = nil
    end
    lobby_string =~ /\d{1,4}/ ? lobby = lobby_string : dan_check = lobby_string
    dan_strings = %w(general dan perdan upperdan gigadan phoenix alldan)
    if player and (dan_check.nil? or dan_strings.include? dan_check)
      text = get_stat(player, man, lobby: lobby, dan: dan_check)
      send_message text
    end
  end

  def say_who
    t_name = @message_text.gsub(/\/whois\s/, '')
    u_name = @db.get_users(t_id: t_name)
    if u_name.size > 0
      text = "#{t_name} известен как"
      u_name.each do |row|
        text += " @#{row[0]}|"
      end
    else
      text = "Я не знаю кто это. Если вы опознали себя, воспользуйтесь командой '/me #{t_name}'."
    end
    send_message text
  end

  def set_user_sch
    dow = @message_text.gsub(/\/set_sch\s/, '').gsub(/\s?\d{1,2}:\d{1,2}\s?-.*/, '')
    dow = dow == '' ? 0 : dow
    if dow.to_i > 7 or dow.to_i < 0
      text = "Invalid day of the week (1-7, 0 is default for whole week). @#{@user['username']}"
      send_message text
      return
    end
    time_from = @message_text.gsub(/\/set_sch\s(\d\s|)/, '').gsub(/\s?-\s?\d{1,2}:\d{1,2}/, '')
    time_to = @message_text.gsub(/\/set_sch\s(\d\s|)\d{1,2}:\d{1,2}\s?-\s?/, '')
    if @db.get_schedule(chat_id: @user['id'], dow: dow).size > 0
      @db.update_schedule chat_id: @user['id'], dow: dow, time_from: time_from, time_to: time_to
    else
      @db.add_schedule chat_id: @user['id'], dow: dow, time_from: time_from, time_to: time_to
    end
  end

  def rm_user_sch
    dow = @message_text.gsub(/\D/, '')
    if dow.to_i > 7 or dow.to_i < 0
      text = "Invalid day of the week (1-7, 0 is default for whole week). #{@user['username']}"
      send_message text
      return
    end
    if @db.get_schedule(chat_id: @user['id'], dow: dow).size > 0
      @db.delete_schedule chat_id: @user['id'], dow: dow
      text = "Schedule on day #{dow} of the week removed. @#{@user['username']}"
      if dow == 0
        text = "Default highlight schedule removed. You will be highlighted until /hloff if not already hloff'ed. @#{@user['username']}"
      end
    elsif dow != 0
      text = "You have no schedule on this day already. @#{@user['username']}"
    else
      text = "You have no default schedule. You will be highlighted until /hloff if not already hloff'ed. @#{@user['username']}"
    end
    send_message text
  end

  def send_user_sch
    text = 'Your schedule of highlights (0 is default) :'
    (0..7).to_a.each do |dow|
      row = @db.get_schedule chat_id: @user['id'], dow: dow
      if row.size == 0
        text += "\n#{dow}: not set yet"
      else
        text += "\n#{dow}: #{row[0][0]} - #{row[0][1]}"
      end
    end
    send_message text
  end

  def send_help
    text = "Available commands:\n/hlon -- enable notify by /mahjong\n/hloff -- disable notify by /mahjong\n/me {tenhou-name} -- bind tenhou name to you\n/stat {(general/dan/upperdan/gigadan/alldan) | (lobby_number)} -- get stat for you in lobby (/me required)\n"
    text += "/set_sch (1-7) {HH:MM - HH:MM} -- set (day of week and) time for highlighting by /mahjong\n/my_sch -- get your schedule of highlighting."
    send_message text
  end

  def send_message(text, chat: nil)
    chat ||= @chat['id']
    RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat, :text => text}}
  end

  def get_users_from_db
    text = ''
    (@db.get_users c_id: 'all').each do |row|
      text += "@#{row[0]}\n"
    end
    send_message text
  end

end

class QueueFromThread < Thread
  def initialize(router, queue)
    @queue = queue
    @router = router
    super{ self.run }
  end

  def run
    while true
      if @queue.empty?
        sleep 1
      else
        message = @queue.pop
        @router.route_queue message
      end
    end
  rescue => err
    @router.logger.error err
  end
end