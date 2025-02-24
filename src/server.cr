require "kemal"
require "kemal-session"
require "./controller/create_db"
require "./controller/main_controler"


get "/" do
  render "src/views/index.ecr"
end

get "/index" do
  render "src/views/index.ecr"
end

get "/index.htm" do
  render "src/views/index.ecr"
end

get "/index.html" do
  render "src/views/index.ecr"
end

get "/:name" do |env|
  name = "/" + env.params.url["name"]
  render "src/views/missing.ecr"
end

get "/register" do |env|
  render "src/views/register.ecr"
end

post "/register_action" do |env|
  begin
    surname = env.params.body["surname"]?
    name = env.params.body["name"]?
    mail = env.params.body["mail"]?
    role_str = env.params.body["role"]?
    password = env.params.body["password"]?

    if surname && name && mail && role_str && password
      create_user(surname.as(String), name.as(String), mail.as(String), role_str.as(String), password.as(String))
      "<mark class='success'>User #{name} #{surname} registered successfully!</mark>"
    else
      "<mark class='error'>Problem with the registration form: one or more fields are missing.</mark>"
    end
  rescue ex : DB::Error
    "<mark class='error'>Database error: #{ex.message}</mark>"
    puts "Database error: #{ex.message}"
  rescue ex : Exception
    puts "An unexpected error occurred: #{ex.message}"
    "<mark class='error'>An unexpected error occurred: #{ex.message}</mark>"
  end
end

struct PendingUser
  include JSON::Serializable

  getter id : String
  getter name : String
  getter surname : String
  getter mail : String
  getter role_requested : String
  getter role_actual : String

  def initialize(@id : String, @name : String, @surname : String, @mail : String, @role_requested : String, @role_actual : String)
  end
end

get "/validate_rights_page" do |env|
  render "src/views/validate_rights_page.ecr"
end

get "/validate_rights" do |env|
  result = "<form hx-post='/validate_rights_action' hx-target='#result' hx-swap='outerHTML'>"
  result += "<table>"
  result += "<thead><tr>"
  result += "<th>Select</th><th>Name</th><th>Surname</th><th>Email</th><th>Requested Role</th><th>Actual Role</th>"
  result += "</tr></thead>"
  result += "<tbody>"
  DB.open DBFILE do |db|
    db.query("SELECT id, name, surname, mail, role_requested, role_actual FROM members WHERE role_requested != role_actual") do |rs|
      rs.each do
        result += "<tr>"
        result += "<td><input type='checkbox' name='user_ids[]' value='" + rs.read(Int32).to_s + "'></td>"
        result += "<td>" + rs.read(String) + "</td>"
        result += "<td>" + rs.read(String) + "</td>"
        result += "<td>" + rs.read(String) + "</td>"
        result += "<td>" + rs.read(String) + "</td>"
        result += "<td>" + rs.read(String) + "</td>"
        result += "</tr>"
      end
    end
  end
  result += "</tbody></table>"
  result += "<button type='submit'>Validate Selected Rights</button>"
  result += "</form>"
  result
end

post "/validate_rights_action" do |env|
  begin
    user_ids = env.params.body["user_ids[]"]?
    if user_ids
      # Ensure we always have an Array[String]. HTMX sends a single value as a String.
      user_ids = user_ids.is_a?(Array(String)) ? user_ids : [user_ids.as(String)]

      DB.open DBFILE do |db|
        user_ids.each do |user_id|
          # Update each user's actual role to match their requested role.
          db.exec "UPDATE members SET role_actual = role_requested WHERE id = ?", user_id.to_i
        end
      end
      "<mark class='success'>Selected users' rights have been validated and updated.</mark>"
    else
      "<mark class='error'>No users were selected for validation.</mark>"
    end
  rescue ex : DB::Error
    puts "Database error: #{ex.message}"
    "<mark class='error'>Database error: #{ex.message}</mark>"
  rescue ex : Exception
    puts "Unexpected error: #{ex.message}"
    "<mark class='error'>An unexpected error occurred: #{ex.message}</mark>"
  end
end

# Initialize session middleware
Kemal::Session.config do |config|
  config.secret = "a very secret key" # Replace with your own secret key
end

# Render the login page
get "/login" do |env|
  render "src/views/login.ecr"
end

# Process login form submission

post "/login" do |env|
  mail = env.params.body["mail"]?
  password = env.params.body["password"]?

  if mail && password
    user = nil
    # Look up the user in the database
    DB.open DBFILE do |db|
      db.query("SELECT id, password, role_actual FROM members WHERE mail = ?", mail.as(String)) do |rs|
        rs.each do
          user_id = rs.read(Int32)
          stored_password = rs.read(String)
          role_actual = rs.read(String)
          if stored_password == password.as(String)
            user = {"id" => user_id, "mail" => mail.as(String), "role" => role_actual}
          end
        end
      end
    end

    if user
      env.session.string("user_id", user["id"].to_s)
      env.session.string("mail", user["mail"].to_s)
      env.session.string("role", user["role"].to_s)
      env.redirect "/"
    else
      "<mark class='error'>Invalid email or password.</mark>"
    end
  else
    "<mark class='error'>Please provide both email and password.</mark>"
  end
end

# Helper class for the profile variables
# (passing dynamic varibles in a template)
class ProfileView
  def initialize(@mail : String)
  end

  ECR.def_to_s "src/views/profile.ecr"
end

# An example of a route that requires authentication
get "/profile" do |env|
  unless env.session.string?("user_id")
    env.redirect "/login"
    next
  end
  mail = env.session.string?("mail") || "unknown"
  ProfileView.new(mail).to_s
end

# Create new article (checking rights)
get "/new_article" do |env|
  unless env.session.string?("user_id")
    env.redirect "/login"
    next
  end

  role = env.session.string?("role") || ""
  unless role == "Editor" || role == "Admin"
    "You do not have sufficient privileges to create new pages."
  else
    render "src/views/new_article.ecr"
  end
end


# create a new article : processsing the form (reading form data)
post "/create_new_article" do |env|
  unless env.session.string?("user_id")
    env.redirect "/login"
    next
  end

  role = env.session.string?("role") || ""
  unless role == "Editor" || role == "Admin"
    "<mark class='error'>Insufficient privileges to create articles.</mark>"
  else
    title       = env.params.body["title"]?
    summary     = env.params.body["summary"]?
    content     = env.params.body["content"]?
    category    = env.params.body["category"]?
    members_only = env.params.body["members_only"]? != nil
    published   = env.params.body["published"]? != nil
    # Use the logged-in user's email as the article's author.
    author_email = env.session.string("mail") || "unknown"

    if title && summary && content && category
      create_article(
        title.as(String),
        content.as(String),
        summary.as(String),
        category.as(String),
        members_only,
        author_email,
        published
      )
    else
      "<mark class='error'>Missing required fields.</mark>"
    end
  end
end


# Create new article : processig
def create_article(title : String,
                   content : String,
                   summary : String,
                   category : String,
                   members_only : Bool,
                   author : String,
                   published : Bool)
  # Connect to DB
  DB.open DBFILE do |db|
    # Retrieve the member's id using their email (author)
    author_id = nil
    db.query("SELECT id FROM members WHERE mail = ?", author) do |rs|
      rs.each do
        author_id = rs.read(Int32)
        break  # Only use the first row
      end
    end
    

    if author_id.nil?
      puts "No member found with email: #{author}"
      "<mark class='error'>Error: No member found with the provided email.</mark>"
    else
      # Insert a new article with the retrieved author_id, including published flag
      time = Time.utc
      db.exec "INSERT INTO Articles (title,
      content,
      summary,
      members_only,
      created,
      modified,
      published,
      category,
      author_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        title, content, summary, members_only, time.to_s, time.to_s, published, category, author_id
      puts "Article successfully inserted for author id #{author_id}"
      "<mark class='success'>Article '#{title}' created successfully.</mark>"
    end
  end
end

### 

class ArticlesView
  # The grouped_articles variable is a Hash where:
  #   Key: category (String)
  #   Value: Array of tuples { id, title, summary, created, category }
  def initialize(@grouped_articles : Hash(String, Array({Int32, String, String, String, String})))
  end

  ECR.def_to_s "src/views/articles.ecr"
end



get "/articles" do |env|
  articles = [] of {Int32, String, String, String, String}   # Each tuple: { id, title, summary, created, category }
  
  # Query the articles, ordering by category then by creation time.
  DB.open DBFILE do |db|
    db.query("SELECT id, title, summary, created, category FROM Articles ORDER BY category ASC, created DESC") do |rs|
      rs.each do
        articles << {rs.read(Int32), rs.read(String), rs.read(String), rs.read(String), rs.read(String)}
      end
    end
  end
  
  # Group the articles by category, which is now at index 4.
  grouped_articles = articles.group_by { |art| art[4] }  # results in Hash(String, Array({Int32, String, String, String, String}))
  
  # Render the articles view.
  ArticlesView.new(grouped_articles).to_s
end


### BEGIN

struct Article
  getter id : Int32
  getter category : String
  getter title : String
  getter summary : String
  getter created : String
  getter content : String

  def initialize(@id : Int32, @category : String, @title : String, @summary : String, @created : String, @content : String)
  end
end

class ArticleDisplayView
  def initialize(@article : Article)
  end

  ECR.def_to_s "src/views/article_display.ecr"
end

get "/article_display/:id" do |env|
  article_id = env.params.url["id"].to_i

  article = Article.new(0, "", "", "", "", "")
  DB.open DBFILE do |db|
    db.query("SELECT id, category, title, summary, created, content FROM Articles WHERE id = ?", article_id) do |rs|
      rs.each do 
        article = Article.new(
          rs.read(Int32),
          rs.read(String),
          rs.read(String),
          rs.read(String),
          rs.read(String),
          rs.read(String)
        )
      end
    end
  end

  if article
    ArticleDisplayView.new(article).to_s
  else
    "Article not found"
  end
end


### END


Kemal.run

# TODO
# ----
# - Formulaire web + endpoint correspondant pour creer un nouveau membre.
# - Idem pour les articles
# - Repertoire pour les images
# - Fonction uplodad pour les images (pour les liens dans les articles).
# - Articles : Rajouter la coolonne categories (plus un frop-ddown)
# - retourner les erreurs dans des div avec des mark (en plus du log).
# - Ajouter colonne password a la table "members"
# - verifier enregtistrement d'un memnbre vs une table (email / rights). Si pas dans la table:demote to visitor.
# - Engerdrer des maots de passe alearoires.
# - Traduire au vol dans la langue de l'usager (idem pour les articles) via JS (Google).
