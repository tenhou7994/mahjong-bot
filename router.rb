# encoding: utf-8
require_relative 'modules'

class Router
  attr_accessor :default_chat_id
  attr_reader :logger

  include Stat_mj
  include Links_mj
  include Schedule_mj
  include Highlights_mj
  include Hints_mj
  include Users_mj
  include Help_mj
  include Bot_mj
  include Message_tg

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

  def route_callback(query)
    @chat = query['message']['chat']
    @user = query['from']
    case query['data']
      when "approved_bot"
        if @user['id'] != @timer_bot.owner_id
          @timer_bot.edit_approve "Бот ожидает начала игры."
          @timer_bot.exit
          @timer_bot = nil
          add_bot
        end
      when "canceled_bot"
        if @user['id'] == @timer_bot.owner_id or user_admin?
          @timer_bot.edit_approve "Ожидание отменено."
          @timer_bot.exit
          @timer_bot = nil
        else
          send_message "Отменить запуск может админ или запустивший его пользователь."
        end
      else
    end
  end

  def route_message(message)
    @message = message
    @logger.info "Incoming json: #{message}"
    @chat = message['chat']
    @user = message['from']
    @message_text = message['text']
    if message['new_chat_member']
      welcome
    end
    case @message_text
      when /^\/hlon\s?$/
        set_highlights_on

      when /^\/hloff(\s.*)?$/
        set_highlights_off

      when /^\/mahjong(\s.*)?$/
        call_to_arms

      when /^\/me\s.+$/
        bind_name

      when /^\/stat3\s?$/
        count_self_stat 3

      when /^\/stat3\s(\d{1,4}|\w*)(\s.*\s?)?$/
        count_hard_stat $1, $2, 3

      when /^\/stat\s?$/
        count_self_stat 4

      when /^\/stat\s(\d{1,4}|\w*)(\s.*\s?)?$/
        count_hard_stat $1, $2, 4

      when /^\/whois\s.+$/
        say_who

      when /^\/whoami$/
        who?

      when /^\/set_sch\s\d?\s?\d{1,2}:\d{1,2}\s?-\s?\d{1,2}:\d{1,2}$/
        set_user_sch

      when /^\/rm_sch\s\d$/
        rm_user_sch

      when /^\/my_sch(\s.+)?$/
        send_user_sch

      when /^\/help(\s.+)?$/
        send_help

      when /^\/help_admin(\s.+)?$/
        send_admin_help if user_admin?

      when /^\/add_bot$/
        send_bot_reply_keyboard

      when /^\/run_bot\s?.*$/
        add_bot_by_people

      when /^\/list$/
        get_users_from_db if user_admin?

      when /^\/links$/
        get_links

      when /^\/add_link(\s\d+)?(\s(https?:\/\/)?([\-\w\.]+)\.([\-\da-z]{2,20}\.?)(\/[\w\.]*)*\/?(.*)?)$/
        add_link $1, $2 if user_admin?

      when /^\/insert_link(\s\d+)?(\s(https?:\/\/)?([\-\w\.]+)\.([\-\da-z]{2,20}\.?)(\/[\w\.]*)*\/?(.*)?)$/
        insert_link $1, $2 if user_admin?

      when /^\/link_desc(\s\d+)(\s.+)$/
        add_desc $1, $2 if user_admin?

      when /^\/swap_link(\s\d+)(\s\d+)$/
        swap_link $1, $2 if user_admin?

      when /^\/rm_link(\s\d+)?$/
        rm_link $1 if user_admin?

      when /^\/hint\s.+/
        add_hint if user_admin?

      when /^\/how_to_win_maajan(\s.+)?$/
        get_hint

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

  def get_admins
    chat = @chat['id'] > 0 ? GROUP_CHAT_ID : @chat['id']
    resp = RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/getChatAdministrators",
                   {:params => {:chat_id => chat}}
    result = (JSON.parse resp)['result']
    result.collect! { |user| user['user']['id'] }
    result
  end

  def get_users_from_db
    text = ''
    (@db.get_users c_id: 'all').each do |row|
      text += "@#{row[0]}\n"
    end
    send_message text
  end

  def user_admin?
    @logger.info "Check user #{@user['id']}"
    get_admins.include? @user['id']
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

class BotTimerThread < Thread
  attr_reader :owner_id

  include Message_tg

  def initialize(time, user_id, chat_id)
    @owner_id = user_id
    @chat_id = chat_id
    @possible = true
    @time = time
    super{ self.run }
  end

  def run
    @possible = false
    send_approve
    sleep @time
    @possible = true
    edit_approve "Истекло время подтверждения запуска бота."
  end

  def send_approve
    text = "Бот ожидает подтверждения другим участником."
    keyboard = {:inline_keyboard => [[:text => 'Подтвердить запуск', :callback_data => 'approved_bot'],
                                   [:text => 'Отменить запуск', :callback_data => 'canceled_bot']]}.to_json
    @message_id = (send_message(text, chat: @chat_id, keyboard: keyboard))['message_id']
  end

  def edit_approve(text)
    markup = {:inline_markup => {}}.to_json
    edit_message @message_id, text, chat: @chat_id, keyboard: markup
  end

  def possible?
    @possible
  end

end

class LockThread < Thread
  attr_reader :owner_id

  def initialize(user_id, chat_id, &block)
    @owner_id = user_id
    @chat_id = chat_id
    @possible = true
    @block = block
    super{ self.run }
  end

  def run
    @possible = false
    @block.call
    @possible = true
  end

  def possible?
    @possible
  end

end
