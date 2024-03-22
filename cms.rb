require 'yaml'
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'redcarpet'
require 'tilt/erubis'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

helpers do
  def sign_in_message
    session[:signed_in] ? "Sign out" : "Sign in"
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def require_signed_in_user
  unless session[:signed_in]
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def valid_file?(file_path)
  File.file?(file_path)
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_path)
  @text = File.read(file_path)

  case File.extname file_path
  when '.md'
    headers["Content-Type"] = "text/html;charset=utf-8"
    render_markdown @text
  else # '.txt'
    headers["Content-Type"] = "text/plain"
    @text
  end
end

def valid_ext?(file_name)
  ext = File.extname file_name
  ext.match?('.') && ext.match?(/[A-Za-z]/)
end

def valid_file_name?(file_name)
  if file_name.size <= 0
    session[:error] = "A name is required."
    return false
  elsif !valid_ext? file_name
    session[:error] = "An extension is required."
    return false
  elsif ["users.yml", "users.yaml"].include? file_name
    unless admin?
      session[:error] = "Requires admin access."
      return false
    end
  end
  true
end

def admin?
  session[:username] == "admin"
end

def restricted_file?(file_name)
  restricted_files = ["users.yml", "users.yaml"]
  restricted_files.include? file_name
end

def valid_user?(username, password)
  @users[username] && BCrypt::Password.new(@users[username]) == password
end

def manage_admin_access
  if admin?
    yield
  else
    session[:error] = "Requires admin access."
    redirect "/"
  end
end

def load_edit_text(file_path)
  @text = File.read(file_path)
  erb :edit
end

get "/" do
  pattern = File.join(data_path, "*")
  @file_names = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :home
end

get "/new" do
  require_signed_in_user

  erb :new_doc
end

get "/:file_name" do
  file_path = File.join(data_path, params[:file_name])

  if restricted_file? params[:file_name]
    manage_admin_access { load_file_content(file_path) }
  elsif valid_file? file_path
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end

# load edit page
get "/:file_name/edit" do
  require_signed_in_user

  @file_name = params[:file_name]
  file_path = File.join(data_path, @file_name)

  if restricted_file? @file_name
    manage_admin_access { load_edit_text(file_path) }
  elsif valid_file? file_path
    load_edit_text(file_path)
  else
    session[:error] = @file_name + " does not exist."
    redirect "/"
  end
end

# create a new file
post "/create" do
  require_signed_in_user

  file_name = params[:file_name].strip

  if valid_file_name? file_name
    file_path = File.join(data_path, file_name)
    File.open(file_path, "w") { |f| f.write params[:content] }
    session[:success] = file_name + " was created."
    redirect "/"
  else
    status 422
    erb :new_doc
  end
end

# update an existing file
post "/:file_name" do
  require_signed_in_user
  file_name = params[:file_name]

  if restricted_file? file_name
    unless admin?
      session[:error] = "Requires admin access."
      redirect "/"
    end
  end

  file_path = File.join(data_path, file_name)
  File.open(file_path, "w") { |f| f.write params[:content] }

  session[:success] = file_name + " was updated."
  redirect "/"
end

post "/:file_name/delete" do
  require_signed_in_user
  file_name = params[:file_name]

  if restricted_file? file_name
    unless admin?
      session[:error] = "Requires admin access."
      redirect "/"
    end
  end

  file_path = File.join(data_path, file_name)
  File.delete file_path

  session[:success] = file_name + " was deleted."
  redirect "/"
end

get "/users/signin" do
  erb :sign_in
end

post "/users/signin" do
  @users = YAML.load_file('data/users.yml')

  if valid_user? params[:username], params[:psw]
    session[:username] = params[:username]
    session[:signed_in] = true
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials."
    status 422
    erb :sign_in
  end
end

post "/users/signout" do
  session.delete :username
  session[:signed_in] = false
  session[:success] = "You have been signed out"
  redirect "/"
end

