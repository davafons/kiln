require "test_helper"

class Kiln::RenderTest < Kiln::TestCase
  Echo = Struct.new(:calls) do
    def get(path)
      calls << path
      Kiln::Response.new(path:, status: 200, headers: { "content-type" => "text/html" }, body: "<p>#{path}</p>")
    end
  end

  test "renders a page through the app outside a build" do
    assert_includes Kiln.render("/about"), "<h1>About</h1>"
  end

  test "raises unless the page responds with 2xx" do
    error = assert_raises(Kiln::Error) { Kiln.render("/not-found") }
    assert_match "404", error.message
  end

  test "during a build each path renders once, with or without a trailing slash" do
    echo = Echo.new([])
    Kiln.building!(renderer: echo) do
      assert_equal "<p>/now</p>", Kiln.render("/now")
      Kiln.render("/now/")
      Kiln.response_for("/now")
    end
    assert_equal [ "/now" ], echo.calls
  end

  test "a page that renders itself raises" do
    looping = Object.new
    def looping.get(path) = Kiln.render(path == "/a" ? "/b" : "/a")

    error = Kiln.building!(renderer: looping) { assert_raises(Kiln::Error) { Kiln.render("/a") } }
    assert_equal "Kiln.render loops: /a -> /b -> /a", error.message
  end

  test "the build writes pages made with Kiln.render and renders each page once" do
    paths = []
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") { paths << it.payload[:path] }
    Kiln::Build.new(output: tmp_output).run

    assert_equal({ "/about/" => "About", "/guide/" => "Guide" }, JSON.parse(tmp_output.join("titles.json").read))
    assert_equal paths.uniq, paths
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
