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
    @db.execute query_main
    @db.execute query_schedule
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

  def close
    @db.close
  end

end
