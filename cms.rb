require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

root = File.expand_path("..", __FILE__)

get "/" do
  @file_names = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :home, layout: :layout
end

get "/:file_name" do
  file_path = root + "/data/" + params[:file_name]

  headers["Content-Type"] = "text/plain"
  @text = File.read(file_path)
end