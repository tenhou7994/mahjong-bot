# encoding: utf-8

require 'nokogiri'
require 'rest-client'

def get_stat(name, man, lobby: nil, dan: nil)
  base_url = "http://arcturus.su/tenhou/ranking/ranking.pl"
  params = {:name => name, :lang => 'en'}
  params.merge!({:l => lobby}) if lobby
  params.merge!({:l => 0000}) if dan
  case dan
    when 'general'
      params.merge!({:r => 224})
    when 'dan'
      params.merge!({:r => 208})
    when 'upperdan', 'perdan'
      params.merge!({:r => 176})
    when 'gigadan', 'phoenix'
      params.merge!({:r => 112})
    when 'alldan'
      params.merge!({:r => 16})
    else
  end
  puts "\n#{params}"
  response = RestClient.get base_url, {:params => params}
  doc = Nokogiri::HTML(response, nil, 'utf-8')
  stat_table = doc.xpath("//h3[text() = \"#{man}man (all time; by day of week)\"]/following-sibling::table")
  if stat_table.size > 0
    stat_rows = stat_table.xpath('tr')
    if lobby.nil? and dan.nil?
      in_lobby = "overall"
    else
      in_lobby = lobby.nil? ? "in #{dan}" : "in lobby #{lobby}"
    end
    stat_text = "#{man} man stat for #{name} #{in_lobby} :\n"
    if (lobby.nil? and dan.nil?) or (lobby and lobby.to_i == 0)
      rank = doc.xpath('//h2[text() = "rank estimation"]/following-sibling::p')
      rank = rank.first.inner_text
      if man == 4
        rank.gsub!(/3man.*$/m,'').gsub!(/^\s*/,'').gsub!(/^4man/m,'Rank')
      elsif man == 3
        rank.gsub!(/4man.*$/m,'').gsub!(/^\s*/,'').gsub!(/^3man/m,'Rank')
      end
      stat_text += rank
    end
    positive_array = [1, 3, 4, 5, 6, 7]
    positive_array << 8 if man == 4
    positive_array.each do |i|
      row = stat_rows[i]
      cells = row.xpath('td')
      stat_text += "#{cells[0].text} | #{cells[1].text}\n"
    end
    stat_text
  else
    "There is no statistic for #{name}"
  end
end