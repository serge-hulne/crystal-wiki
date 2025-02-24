require "db"
require "sqlite3"
require "./db_constants"

enum Role
  Visitor
  Member
  Editor
  Admin
end

struct Privilege
  property can_read : Bool
  property can_read_private_articles : Bool
  property can_write_articles : Bool
  property can_modify_articles : Bool

  def initialize(@can_read : Bool,
                 @can_read_private_articles : Bool,
                 @can_write_articles : Bool,
                 @can_modify_articles : Bool)
  end
end

Rights = {
  Role::Visitor => Privilege.new(
    can_read: true,
    can_read_private_articles: false,
    can_write_articles: false,
    can_modify_articles: false
  ),

  Role::Member => Privilege.new(
    can_read: true,
    can_read_private_articles: true,
    can_write_articles: false,
    can_modify_articles: false
  ),

  Role::Editor => Privilege.new(
    can_read: true,
    can_read_private_articles: true,
    can_write_articles: true,
    can_modify_articles: false
  ),

  Role::Admin => Privilege.new(
    can_read: true,
    can_read_private_articles: true,
    can_write_articles: true,
    can_modify_articles: true
  ),
}


def test
  puts
  puts "Visitor privileges: #{Rights[Role::Visitor]}"
  puts "Visitor can write articles: #{Rights[Role::Visitor].can_write_articles}"
  puts "Admin can write articles: #{Rights[Role::Admin].can_write_articles}"
end

def create_user(surname : String,
                name : String,
                mail : String,
                role_requested : String,
                password : String)
  # Connect to DB
  DB.open DBFILE do |db|
    # Insert a new member record, storing the role as its string representation
    db.exec "INSERT INTO members (surname, name, mail, role_requested, role_actual, password)
             VALUES (?, ?, ?, ?, ?, ?)",
      surname, name, mail, role_requested.to_s, "Visitor", password #
    puts "User registered: #{name} #{surname} with role requested #{role_requested} and password #{password}"
  end
end

def str_2_role(role_str : String)
  Role
  # Basic conversion from String to Role enum:
  role = case role_str
         when "Visitor"
           Role::Visitor
         when "Member"
           Role::Member
         when "Editor"
           Role::Editor
         when "Admin"
           Role::Admin
         else
           Role::Visitor # default/fallback
         end
end
