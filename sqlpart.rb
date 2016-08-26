# encoding: utf-8

require 'sqlite3'


class DBC
  def initialize
    @db = SQLite3::Database.new DB_FILE.to_s
    self.create_tables
  end

  def create_tables
    query_main = "create table if not exists members
      (chat_id int unique, username text, tenhou_id text, hl_status boolean);"
    query_schedule = "create table if not exists schedules
      (chat_id int, d_of_w int, time_from text, time_to text)"
    query_links = "create table if not exists links(id int unique, link text, desc text);"
    query_miko_hints = 'create table if not exists hints(hint text unique);'
    @db.execute query_main
    @db.execute query_schedule
    @db.execute query_links
    @db.execute query_miko_hints
  end

  def add_user(c_id, username: ,t_id: nil , hl_s: 1)
    username = "'#{username}'"
    t_id = t_id.nil? ? 'null' : "'#{t_id}'"
    query = "insert or replace into members values (#{c_id}, #{username},#{t_id}, #{hl_s})"
    @db.execute query
  end

  def update_user(c_id, username:, t_id: nil, hl_s: nil)
    username = username.nil? ? 'null' : "'#{username}'" 
    if t_id
      query = "update members set tenhou_id = '#{t_id}', username = #{username} where chat_id = #{c_id};"
    elsif hl_s
      query = "update members set hl_status = #{hl_s}, username = #{username} where chat_id = #{c_id};"
    end
    @db.execute query
  end

  def get_users(c_id: nil, t_id: nil, hl_s: nil)
    if t_id
      query = "select username, hl_status from members where tenhou_id = '#{t_id}';"
    elsif c_id
      query = "select username, tenhou_id, hl_status from members where chat_id = #{c_id};"
      if c_id == 'all'
        query = 'select username from members where username is not null;'
      end
    elsif hl_s
      query = "select username, chat_id from members where hl_status = #{hl_s};"
    end
    @db.execute query
  end

  def add_schedule(chat_id:, dow: 0, time_from:, time_to:)
    query = "insert or replace into schedules values (#{chat_id}, #{dow}, '#{time_from}', '#{time_to}');"
    @db.execute query
  end

  def update_schedule(chat_id:, dow: 0, time_from:, time_to:)
    query = "update schedules set time_from='#{time_from}', time_to='#{time_to}' where chat_id=#{chat_id} and d_of_w=#{dow};"
    @db.execute query
  end

  def delete_schedule(chat_id:, dow:)
    query = "delete from schedules where chat_id=#{chat_id} and d_of_w=#{dow};"
    @db.execute query
  end

  def get_schedule(chat_id:, dow: 0)
    query = "select time_from, time_to from schedules where chat_id = #{chat_id} and d_of_w=#{dow};"
    @db.execute query
  end

  def add_link(id, link)
    desc = 'no description'
    query = "insert or replace into links values (#{id}, '#{link}', '#{desc}');"
    @db.execute query
  end

  def add_link_desc(id, desc)
    query = "update links set desc='#{desc}' where id=#{id};"
    @db.execute query
  end

  def update_link_id(id)
    query = "update links set id=#{id-1} where id=#{id};"
    @db.execute query
  end

  def get_link(id)
    query = "select id from links where id=#{id};"
    @db.execute query
  end

  def get_links
    query = 'select * from links order by id asc;'
    @db.execute query
  end

  def get_last_link_id
    query_last_index = 'select max(id) from links;'
    @db.get_first_value query_last_index
  end

  def swap_links(id_1, id_2)
    temp_id = get_last_link_id + 1000
    query_swap_1 = "update links set id=#{temp_id} where id=#{id_2};"
    query_swap_2 = "update links set id=#{id_2} where id=#{id_1};"
    query_swap_3 = "update links set id=#{id_1} where id=#{temp_id};"
    @db.execute query_swap_1
    @db.execute query_swap_2
    @db.execute query_swap_3
  end

  def delete_link(id)
    query = "delete from links where id=#{id};"
    @db.execute query
    arr = get_links.collect do |link|
      if link[0] > id
        link[0]
      end
    end
    arr.compact.each do |i|
      update_link_id i
    end
  end

  def add_hint(hint)
    query = "insert or replace into hints values ('#{hint}');"
    @db.execute query
  end

  def get_hints
    query = "select * from hints;"
    @db.execute query
  end

  def close
    @db.close
  end

end
