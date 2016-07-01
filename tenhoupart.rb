# encoding: utf-8

require 'nokogiri'
require 'rest-client'

def get_stat(name, lobby)
  base_url = "http://arcturus.su/tenhou/ranking/ranking.pl"
  params = {:name => name, :l => lobby, :lang => 'en'}
  response = RestClient.get base_url, {:params => params}
  doc = Nokogiri::HTML(response, nil, 'utf-8')
  stat_table = doc.xpath('//h3[text() = "4man (all time; by day of week)"]/following-sibling::table')
  if stat_table.size > 0
    stat_rows = stat_table.xpath('tr')
    stat_text = "4 man stat for #{name} in lobby #{lobby} :\n"
    stat_rows.delete(stat_rows[0])
    stat_rows.each do |row|
      cells = row.xpath('td')
      stat_text += "#{cells[0].text} | #{cells[1].text}\n"
    end
    stat_text
  else
    "There is no statistic for #{name}"
  end
end
