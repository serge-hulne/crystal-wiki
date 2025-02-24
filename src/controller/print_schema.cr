require "db"
require "sqlite3"

DB.open "sqlite3:./file.db" do |db|
  db.query("SELECT name, sql FROM sqlite_master WHERE type = 'table'") do |result|
    result.each do
      name = result.read(String)
      sql = result.read(String)
      puts "Table: #{name}"
      puts "SQL: #{sql}"
    end
  end
end
