require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'redcarpet'
require 'tilt/erubis'

root = File.expand_path("..", __FILE__)

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

get "/" do
  @file_names = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :home, layout: :layout
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
  when '.txt'
    headers["Content-Type"] = "text/plain"
    @text
  end
end

get "/:file_name" do
  file_path = root + "/data/" + params[:file_name]

  if valid_file? file_path
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end