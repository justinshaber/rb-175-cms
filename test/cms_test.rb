ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_home
    get "/"
    file_names = ["about.txt", "history.txt", "changes.txt"]
    result = file_names.all? do |file_name|
      last_response.body.include? file_name
    end

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert result
  end

  def test_view_file_content
    get "/about.txt"
    file_path = "data/about.txt"
    text = File.read(file_path)

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal text, last_response.body
  end

  def test_invalid_file_name
    get "/notafile.txt"
    file_path = "data/notafile.txt"

    refute File.file?(file_path)
    assert_equal 302, last_response.status
    assert_equal "http://example.org/", last_response["Location"]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist."

    get "/"

    assert_equal 200, last_response.status
    refute_includes last_response.body, "notafile.txt does not exist."
  end

  def test_markdown
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"] 
    assert_includes last_response.body, "<strong>Carmel Middle School</strong>"
  end

  def test_invalid_file_name_from_edit_page
    get "/notafile.txt/edit"
    file_path = "data/notafile.txt"

    refute File.file?(file_path)
    assert_equal 302, last_response.status
    assert_equal "http://example.org/", last_response["Location"]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist."

    get "/"

    assert_equal 200, last_response.status
    refute_includes last_response.body, "notafile.txt does not exist."
  end

  def test_edit_page
    get "/about.txt/edit"
    file_path = "data/about.txt"
    text = File.read(file_path)

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, text
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_post_edit
    post "/about.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "about.txt was updated."

    get "/about.txt"
    text = File.read("data/about.txt")

    assert_equal 200, last_response.status
    assert_equal text, "new content"
  end
end