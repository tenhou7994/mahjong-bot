require 'sqlite3'


class DBC
  def initialize
    @db = SQLite3::Database.new DB_FILE.to_s
    self.create_table
  end

  def create_table
    query = "create table if not exists members(chat_id int unique, username text, tenhou_id text, hl_status boolean);"
    @db.execute query
  end

  def add_user(c_id, username,t_id: 'null', hl_s: 1)
    t_id = "'#{t_id}'" if t_id != 'null'
    query = "insert or replace into members values (#{c_id}, '#{username}',#{t_id}, #{hl_s})"
    @db.execute query
  end

  def update_user(c_id, username, t_id: nil, hl_s: nil)
    if t_id
      query = "update members set tenhou_id = '#{t_id}' where chat_id = #{c_id};"
    elsif hl_s
      query = "update members set hl_status = #{hl_s}, username = '#{username}' where chat_id = #{c_id};"
    end
    @db.execute query
  end

  def get_users(c_id: nil, t_id: nil, hl_s: nil)
    if t_id
      query = "select username, hl_status from members where tenhou_id = '#{t_id}';"
    elsif c_id
      query = "select username, tenhou_id, hl_status from members where chat_id = #{c_id};"
    elsif hl_s
      query = "select username, tenhou_id from members where hl_status = #{hl_s};"
    end
    @db.execute query
  end

  def close
    @db.close
  end

end
