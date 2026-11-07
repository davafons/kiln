require "test_helper"

class Kiln::ServerTest < Kiln::TestCase
  setup do
    { "index.html" => "home", "about.html" => "about", "assets/app.css" => "body{}", "_redirects" => "/old /about 301\n" }.each do |file, body|
      tmp_output.join(file).dirname.mkpath
      tmp_output.join(file).write(body)
    end
  end

  def get(path) = Rack::MockRequest.new(Kiln::Server.new(tmp_output)).get(path)

  test "serves files with content types" do
    response = get("/about")
    assert_equal 200, response.status
    assert_equal "text/html", response.content_type
    assert_equal "about", response.body

    assert_equal "text/css", get("/assets/app.css").content_type
    assert_equal "home", get("/").body
  end

  test "follows exact _redirects rules" do
    response = get("/old")
    assert_equal 301, response.status
    assert_equal "/about", response.location
  end

  test "serves 404.html for misses" do
    assert_equal 404, get("/missing").status
    assert_equal "Not found\n", get("/missing").body

    tmp_output.join("404.html").write("lost")
    response = get("/missing")
    assert_equal 404, response.status
    assert_equal "lost", response.body
    assert_equal "text/html", response.content_type
  end
end
