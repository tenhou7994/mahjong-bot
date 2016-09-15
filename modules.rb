module Stat_mj
  def count_self_stat(man)
    user = @db.get_users(c_id: @user['id'])
    if user.size > 0
      player = user[0][1]
      text = get_stat player, man
    else
      text = 'У Вас нет привязанного тенхо-ника. Используйте /me {tenhou_name} для привязки.'
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
    else
      text = 'У Вас нет привязанного тенхо-ника. Используйте /me {tenhou_name} для привязки.'
    end
    send_message text
  end
end

module Links_mj
  def add_link(id, link)
    link.lstrip!
    if id.nil? or (@db.get_link id).nil?
      @db.add_link id, link
    else
      id = id.lstrip.to_i
      @db.add_link id, link, update_type:'update'
    end
  end

  def insert_link(id, link)
    if id.nil?
      add_link id, link
    else
      link.lstrip!
      id = id.lstrip.to_i
      @db.add_link id, link, update_type: 'insert'
    end
  end

  def add_desc(id, desc)
    id = id.lstrip!.to_i
    desc.lstrip!
    @db.add_link_desc id, desc
  end

  def get_links
    links = @db.get_links
    if links.size > 0
      text = 'Useful links:'
      links.each do |link|
        text += "\n#{link[0]}. <a href=\"#{link[1]}\">#{link[2]}</a>"
      end
    else
      text = 'There are no links yet.'
    end
    send_message text, formatted: true
  end

  def swap_link(id_1, id_2)
    id_1.lstrip!.to_i
    id_2.lstrip!.to_i
    @db.swap_links id_1, id_2
  end

  def rm_link(id)
    id = id.lstrip!.to_i
    link = @db.get_link id
    if link.nil?
    else
      @db.delete_link id
    end
  rescue => err
    @logger.error "rm_link from #{@user['id']} with id #{id}"
    @logger.fatal err
  end
end

module Schedule_mj
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
end

module Highlights_mj
  def set_highlights_on
    if @user['username'].nil?
      text = 'Пожалуйста, установите никнейм в профиле telegram.'
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
      text = 'У вас нет никнейма в telegram, нотификации выключены по-умолчанию.'
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
end

module Hints_mj
  def add_hint
    @message_text.gsub!(/\/hint\s/,'')
    arr = @message_text.split(/(\r\n|\n)/)
    arr.each{|hint| @db.add_hint hint}
  end

  def get_hint
    text = @db.get_hints.flatten.sample || "НИКАК."
    text = text =~ /^\s*$/ ? "НИКАК." : text
    send_message text
  end
end

module Users_mj
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

  def who?
    t_name = @db.get_users(c_id: @user['id'])
    if t_name.size > 0
      text = "Похоже что @#{t_name[0][0]} - это #{t_name[0][1]}."
    else
      text = 'У Вас нет привязанного тенхо-ника. Используйте /me {tenhou_name} для привязки.'
    end
    send_message text
  end
end

module Help_mj
  def send_help
    text = "Доступные команды:\n/hlon — Включить нотификацию для /mahjong\n/hloff — Выключить нотификацию для /mahjong\n"
    text += "/me {tenhou-name} — Привязать тенхо-ник к телеграм аккаунту\n/whois {tenhou-name} — Узнать кто скрывается за тенхо-ником\n"
    text += "/stat {(general/dan/upperdan/gigadan/alldan) | (lobby_number)} (tenhou-name) — Получить статистику для указаного лобби(для указанного тенхо-ника, если не указано - для привязанного)\n/stat3 - То же, что и /stat для игры на троих\n"
    text += "/set_sch (1-7) {HH:MM - HH:MM} — Установить (день недели, если не указан то для всех дней) расписание нотификаций для /mahjong\n/my_sch — Посмотреть свое расписание нотификаций\n"
    text += "/links — Список полезных ссылок, если вы хотите видеть тут свою ссылку - обратитесь к админу группы\n"
    text += "/how_to_win_maajan — Получить ответ на вопрос \"Как выиграть в маджонг?\" от мудрого Бота.\n"
    text += "/add_bot - Попросить бота нажать кнопочку."
    send_message text
  end

  def send_admin_help
    text = "Available admin commands:\n/add_link [id] {link} — Добавить ссылку в список, если указан id то вставит вместо линка с этим id\n"
    text += "/insert_link [id] {link} - Добавить ссылку в определенное место списка, если id не указан ведет себя как /add_link\n"
    text += "/link_desc {id} {description} — Добавить/изменить описание ссылке с указанным id\n/swap_link {id_1} {id_2} — Поменять местами ссылки с указанными id\n"
    text += "/rm_link {id} — Удалить ссылку с указанным id(после удаления id меняются!)\n"
    text += "/hint {text} - Добавить текст для вывода при использовании /how_to_win_maajan (можно вводить несколько, разделяются переводом строки)\n"
    text += "/list - Вывести известных боту людей из телеграма. (аккуратно, не используйте в чате без не обходимости, хайлайтит всех)"
    send_message text
  end

  def welcome
    username = @message['new_chat_member']['username'] ? '@' + @message['new_chat_member']['username'] : @message['new_chat_member']['first_name']
    send_message "Привет #{username}! Добро пожаловать в маджонгач. Снова."
    set_highlights_on
    send_help
  end
end

module Bot_mj
  def add_bot(no_aka: 0, kuitan: 0, fast: 0, hanchan: 1, threesome: 0, lobby: 7994)
    @rules.each do |rule|
      case rule
        when /^(!)?aka$/
          no_aka = 1 if $1
        when /^(!)?kuitan$/
          kuitan = 1 if $1.nil?
        when /^(!)?hanchan$/
          hanchan = 0 if $1
        when /^(!)?three$/
          threesome = 1 if $1.nil?
        when /^(!)?fast$/
          fast = 1 if $1.nil?
        when /^(0|\d{4})$/
          lobby = $1.to_i
        else
      end
    end

    button = 1 + (kuitan*2) + (no_aka*4) + (hanchan*8) + (threesome*16) + (fast*64)
    params_hash = {:lobby => lobby, :type => button, :name => 'ID582D7C90-ABf9JQAe'}
    resp = RestClient.get "http://mahjongbot.herokuapp.com/startBot", {:params => params_hash}
    @bot_id = (JSON.parse resp.body)['id']
    @logger.info "New bot with ID - #{@bot_id}, with params #{params_hash}."
    send_message "Бот ожидает игры в лобби #{lobby}."
  end

  def bot_offline?
    if @bot_id.nil?
      return true
    end
    resp = RestClient.get "http://mahjongbot.herokuapp.com/info", {:params => {:id => @bot_id}}
    status = (JSON.parse resp.body)['status']
    if status == 'error'
      true
    else
      false
    end
  end

  def add_bot_by_people
    if bot_offline?
      if @timer_bot.nil? || @timer_bot.possible?
        @timer_bot = BotTimerThread.new 600, @user['id'], @chat['id']
      else
        send_message "Бот уже ожидает подтверждения."
        return
      end
      @rules = @message_text.split.uniq
    else
      send_message 'Бот уже ожидает/играет, к сожалению пока адекватно играть может только один бот.'
    end
  end

  def send_bot_reply_keyboard
    if bot_offline?
      buttons = [
          [{:text => "/run_bot !hanchan kuitan !aka"}, {:text => "/run_bot kuitan !aka"}],
          [{:text => "/run_bot !hanchan !aka"}, {:text => "/run_bot !aka"}],
          [{:text => "/run_bot !hanchan"}, {:text => "/run_bot"}],
          [{:text => "/run_bot !hanchan fast"}, {:text => "/run_bot fast"}],
          [{:text => "/run_bot !hanchan three"}, {:text => "/run_bot three"}],
          [{:text => "/run_bot !hanchan three fast"}, {:text => "/run_bot three fast"}],
          [{:text => "Я передумал"}]
      ]
      keyboard = {:keyboard => buttons, :one_time_keyboard => true, :selective => true}.to_json
      send_message "Выберите кнопку для бота(порядок такой же, как и в флеш-клиенте).", keyboard: keyboard
    else
      send_message 'Бот уже ожидает/играет, к сожалению пока адекватно играть может только один бот.'
    end
  end
end