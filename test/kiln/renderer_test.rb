require "test_helper"

class Kiln::RendererTest < Kiln::TestCase
  test "renders a page through the full Rails stack" do
    response = Kiln::Renderer.new(dummy_app, host: "example.com").get("/about")

    assert_equal 200, response.status
    assert response.html?
    assert_equal Encoding::UTF_8, response.body.encoding
    assert_includes response.body, "<html>"
  end

  test "sends the host and https" do
    app = ->(env) { [ 200, { "Content-Type" => "text/plain" }, [ "#{env["HTTP_HOST"]} #{env["HTTPS"]} #{env["rack.url_scheme"]}" ] ] }
    response = Kiln::Renderer.new(app, host: "example.com").get("/")

    assert_equal "example.com on https", response.body
    assert_equal "text/plain", response.headers["content-type"]
  end

  test "does not follow redirects" do
    response = Kiln::Renderer.new(dummy_app, host: "example.com").get("/old-about")

    assert_equal 301, response.status
    assert response.redirect?
    assert_equal "https://example.com/about", response.location
  end

  test "raises app exceptions instead of rendering an error page" do
    renderer = Kiln::Renderer.new(dummy_app, host: "example.com")

    # RoutingError is rescuable, so the dummy's :rescuable setting would otherwise render a 404 page.
    error = assert_raises(ActionController::RoutingError) { renderer.get("/posts/missing") }
    assert_equal "No post missing", error.message
    assert_equal :rescuable, dummy_app.env_config["action_dispatch.show_exceptions"]
  end

  test "keeps binary bodies binary" do
    bytes = "\x89PNG\r\n\x1A\n\xFF".b
    app = ->(_env) { [ 200, { "content-type" => "image/png" }, [ bytes ] ] }
    response = Kiln::Renderer.new(app, host: "example.com").get("/logo.png")

    assert_equal Encoding::BINARY, response.body.encoding
    assert_equal bytes, response.body
  end

  test "returns text bodies as UTF-8" do
    app = ->(_env) { [ 200, { "content-type" => "application/json" }, [ "{\"name\":\"日本\"}".b ] ] }
    response = Kiln::Renderer.new(app, host: "example.com").get("/data.json")

    assert_equal Encoding::UTF_8, response.body.encoding
    assert_equal "{\"name\":\"日本\"}", response.body
  end
end
