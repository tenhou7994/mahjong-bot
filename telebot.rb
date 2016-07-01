require 'rest-client'
require 'sinatra'
require 'json'
load 'conf.rb'
load 'sqlpart.rb'
load 'tenhoupart.rb'

$db = DBC.new

set :port, 8888

response = RestClient.post("https://api.telegram.org/bot#{BOT_TOKEN}/setWebhook", {:url => SERVER_URL, :certificate => File.new("server.crt", 'rb')})

print response.code

post '/_callback_mj' do
  update = JSON.parse request.body.read
  route_message update["message"]
  200
end

helpers do
  def route_message(message)
    chat = message["chat"]
    user = message["from"]
    case message["text"]
      when /\/hlon\s?.*/
        if user["username"].nil?
          text = "Please set your username in telegram profile."
          RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}
        else
          if $db.get_users(c_id: user["id"]).size > 0
            $db.update_user user["id"], user["username"], hl_s:1
          else
            $db.add_user user["id"], user["username"]
          end
        end

      when /\/hloff\s?.*/
        if user["username"].nil?
          text = "You have no username, highlights disabled by default."
          RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}
        else
          if $db.get_users(c_id: user["id"]).size > 0
            $db.update_user user["id"], user["username"], hl_s:0
          else
            $db.add_user user["id"], user["username"], hl_s:0
          end
        end

      when /\/mahjong\s?.*/
        text = "@#{user["username"]} призывает нажать кнопку в лобби tenhou.net/0?L7994 (tenhou.net/3/beta.html?L7994) \n"
        $db.get_users(hl_s:1).each do |row|
          text += "@#{row[0]} | "
        end
        RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}

      when /\/me\s.*/
        name = message["text"].gsub(/\/me\s/,'')
        if $db.get_users(c_id: user["id"]).size > 0
          $db.update_user user["id"], user["username"], t_id:name
        else
          $db.add_user user["id"], user["username"], t_id:name
        end
        text = "Никнейм #{name} на tenhou ассоциирован с Вами. Теперь Вы можете воспользоваться командой /stat {lobby_number}"
        RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}

      when /\/stat\s\d*/
        u_name = $db.get_users(c_id: user["id"])
        lobby = message["text"].gsub!(/\D/,'')
        if u_name.size > 0
          text = get_stat(u_name[0][1], lobby)
          RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}
        end
      
      when /\/whois\s.*/
        t_name = message["text"].gsub(/\/whois\s/,'')
        u_name = $db.get_users(t_id: t_name)
        if u_name.size > 0
          text = "#{t_name} известен как"
          u_name.each do |row|
            text += " @#{row[0]}|"
          end
        else
          text = "Я не знаю кто это. Если вы опознали себя, воспользуйтесь командой '/me #{t_name}' ."
        end
        RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage", {:params => {:chat_id => chat["id"], :text => text}}
      
      else
    end

  end
end
