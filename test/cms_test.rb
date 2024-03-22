ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  # test/cms_test.rb
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  # access the session data
  def session
    last_request.env["rack.session"]
  end

  # used to circumvent sign in process for each test
  def admin_session
    { "rack.session" => { signed_in: true } }
  end

  def test_home
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    file_names = ["about.md", "changes.txt"]
    result = file_names.all? do |file_name|
      last_response.body.include? file_name
    end

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert result
  end

  def test_view_file_content
    create_document "about.txt", "example content"
    get "/about.txt"

    file_path = "test/data/about.txt"
    text = File.read(file_path)

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal text, last_response.body
  end

  def test_invalid_file_name
    get "/notafile.txt"
    file_path = "test/data/notafile.txt"

    refute File.file?(file_path)
    assert_equal 302, last_response.status
    assert_equal "http://example.org/", last_response["Location"]
    assert_equal "notafile.txt does not exist.", session[:error]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist."
    assert_nil session[:error]

    get "/"

    assert_equal 200, last_response.status
    assert_nil session[:error]
  end

  def test_markdown
    create_document "about.md", "**Carmel Middle School**"
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"] 
    assert_includes last_response.body, "<strong>Carmel Middle School</strong>"
  end

  def test_invalid_file_name_from_edit_page
    get "/notafile.txt/edit", {}, admin_session
    file_path = "test/data/notafile.txt"
    refute File.file?(file_path)
    assert_equal 302, last_response.status
    assert_equal "http://example.org/", last_response["Location"]
    assert_equal "notafile.txt does not exist.", session[:error]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_nil session[:error]

    get "/"
    assert_equal 200, last_response.status
    assert_nil session[:error]
  end

  def test_edit_page
    create_document "about.txt", "example content"
    get "/about.txt/edit", {}, admin_session
    file_path = "test/data/about.txt"
    text = File.read(file_path)

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, text
    assert_includes last_response.body, "example content"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_post_edit
    create_document "about.txt"

    post "/about.txt", {content: "new content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal session[:success], "about.txt was updated."

    get last_response["Location"]
    assert_equal 200, last_response.status
    refute session[:success]

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_delete
    create_document "about.md"
    create_document "changes.txt"

    post "/about.md/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal session[:success], "about.md was deleted."

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt"
    refute session[:success]

    get "/"
    assert_includes last_response.body, "changes.txt"
    refute_includes last_response.body, "about.md"
  end

  def test_create_new_document
    post "/create", {file_name: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:success]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_signin_page
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<b>Password</b></label>"
  end

  def test_invalid_signin
    post "/users/signin", username: "invalid admin", psw: "invalid password"

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials."
    assert_includes last_response.body, "invalid admin"
  end

  def test_valid_signin
    create_document "about.txt"
    post "/users/signin", username: "admin", psw: "secret"

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert session[:signed_in]
  end

  def test_signout_button
    create_document "about.txt"
    get "/", {}, admin_session


    post "/users/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out", session[:success]

    get last_response["Location"]
    assert_equal 200, last_response.status
    refute session[:signed_in]
  end

  def test_signedout_homepage
    create_document "about.txt"
    get "/"

    assert_equal 200, last_response.status
    assert_nil session[:signed_in]
  end

  def test_signedin_homepage
    create_document "about.txt"
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert session[:signed_in]
  end

  def test_unable_to_edit
    create_document "about.txt"
    get "/about.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_unable_to_visit_new_page
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_unable_to_create_new
    post "/create"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_unable_to_update
    create_document "about.txt"
    post "/about.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_unable_to_delete
    post "/about.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_unable_to_delete
    create_document "about.txt"
    post "/about.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_admin_update_users
    create_document "users.yml"
    post "/users.yml", {}, { "rack.session" => { signed_in: true, username: "admin" } }

    assert_equal 302, last_response.status
    assert_equal "users.yml was updated.", session[:success]
  end

  def test_non_admin_cannot_update_users
    create_document "users.yml"
    post "/users.yml", {}, { "rack.session" => { signed_in: true, username: "bill" } }

    assert_equal 302, last_response.status
    assert_equal "Requires admin access.", session[:error]
  end

  def test_admin_delete_user_file
    create_document "users.yml"
    post "/users.yml/delete", {}, { "rack.session" => { signed_in: true, username: "admin" } }

    assert_equal 302, last_response.status
    assert_equal "users.yml was deleted.", session[:success]
  end

  def test_non_admin_cannot_delete_user_file
    create_document "users.yml"
    post "/users.yml/delete", {}, { "rack.session" => { signed_in: true, username: "bill" } }

    assert_equal 302, last_response.status
    assert_equal "Requires admin access.", session[:error]
  end
end