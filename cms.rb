require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'redcarpet'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
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

get "/" do
  pattern = File.join(data_path, "*")
  @file_names = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :home, layout: :layout
end

get "/new" do
  erb :new_doc, layout: :layout
end

get "/:file_name" do
  file_path = File.join(data_path, params[:file_name])

  if valid_file? file_path
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  @file_name = params[:file_name]
  file_path = File.join(data_path, @file_name)

  if valid_file? file_path
    @text = File.read(file_path)
    erb :edit, layout: :layout
  else
    session[:error] = @file_name + " does not exist."
    redirect "/"
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
  end
  true
end

post "/create" do
  file_name = params[:file_name].strip

  if valid_file_name? file_name
    file_path = File.join(data_path, file_name)
    File.open(file_path, "w") { |f| f.write params[:content] }
    session[:success] = file_name + " was created."
    redirect "/"
  else
    status 422
    erb :new_doc, layout: :layout
  end
end

post "/:file_name" do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  File.open(file_path, "w") { |f| f.write params[:content] }

  session[:success] = file_name + " was updated."
  redirect "/"
end

post "/:file_name/delete" do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  File.delete file_path

  session[:success] = file_name + " was deleted."
  redirect "/"
end

