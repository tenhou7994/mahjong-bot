# encoding: utf-8

require 'rest-client'
require 'sinatra/base'
require 'json'
require 'time'
require 'thread'

require_relative 'conf'
require_relative 'sqlpart'
require_relative 'tenhoupart'
require_relative 'router'
require_relative 'tenhou-bot'



class Teleserver < Sinatra::Application

  set :port, CALLBACK_PORT

  RestClient.post("https://api.telegram.org/bot#{BOT_TOKEN}/setWebhook", {:url => SERVER_URL, :certificate => File.new("server.crt", 'rb')})

  post CALLBACK_URL do
    update = JSON.parse request.body.read
    message = update["message"].nil? ? update["edited_message"] : update["message"]
    $router.route_message message
    200
  end

end

db = DBC.new
$queue_from_chat = Queue.new
$router = Router.new db

$router.default_chat_id = GROUP_CHAT_ID

threads = Array.new
threads << Thread.new do
  Teleserver.run!
end

threads << Thread.new do

  tr = TenhouRunner.new '7994bot', lobby: '7994'

  tr.bot.from_chat = $queue_from_chat

  tr.start
end

threads << Thread.new do

  QueueFromThread.new $router, $queue_from_chat

end

threads << Thread.new {
  sleep 1 until Teleserver.running?

  def shut_down
    RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/setWebhook"
    $stdout << "\n set webhook to null\n"
    response = RestClient.get "https://api.telegram.org/bot#{BOT_TOKEN}/getUpdates"
    $stdout << "get updates \n"
    update = JSON.parse response.body
    last_update = update["result"].size > 0 ? update["result"].last : nil
    if last_update.nil?
      $stdout << "there is no updates\n"
    else
      $stdout << "requests offset\n"
      RestClient.get("https://api.telegram.org/bot#{BOT_TOKEN}/getUpdates?offset=#{last_update['update_id'].to_i + 1}") 
    end
  end

  # Trap ^C
  Signal.trap("INT") {
    shut_down
    exit
  }

  # Trap `Kill `
  Signal.trap("TERM") {
    shut_down
    exit
  }
}

threads.each { |thread| thread.join }
