require "db"
require "sqlite3"
require "./db_constants"

def create_db
  # Connect to DB
  DB.open DBFILE do |db|
    # Enable foreign key constraints in SQLite
    db.exec "PRAGMA foreign_keys = ON"

    begin
      # Create the members table with an auto-incrementing primary key
      db.exec "CREATE TABLE members (
        id INTEGER PRIMARY KEY,
        surname TEXT,
        name TEXT,
        mail TEXT UNIQUE,
        role_requested TEXT,
        role_actual TEXT,
        password TEXT
    )"
    rescue ex : Exception
      puts "An unexpected DB error occurred: #{ex.message}"
    end

    # Create the Articles table and reference members.id as the author_id
    begin
      db.exec "CREATE TABLE articles (
        id INTEGER PRIMARY KEY,
        title TEXT,
        content TEXT,
        summary TEXT,
        members_only BOOLEAN,
        created DATE,
        modified DATE,
        published BOOLEAN,
        category TEXT,
        author_id INTEGER,
        FOREIGN KEY(author_id) REFERENCES members(id)
      )"
    rescue ex : Exception
      puts "An unexpected DB error occurred: #{ex.message}"
    end
  end # end DB.open
end   # end def create_db

# create_db()
