require "test_helper"

class Kiln::StaticResolverTest < Kiln::TestCase
  setup do
    {
      "index.html" => "home",
      "about.html" => "about",
      "now/index.html" => "now",
      "assets/app.css" => "css",
      "with space.html" => "space"
    }.each do |file, body|
      tmp_output.join(file).dirname.mkpath
      tmp_output.join(file).write(body)
    end
    @resolver = Kiln::StaticResolver.new(tmp_output)
  end

  def resolved(path) = @resolver.resolve(path)&.relative_path_from(tmp_output.expand_path)&.to_s

  test "follows static host resolution" do
    assert_equal "index.html", resolved("/")
    assert_equal "index.html", resolved("")
    assert_equal "assets/app.css", resolved("/assets/app.css")
    assert_equal "about.html", resolved("/about")
    assert_equal "about.html", resolved("/about.html")
    assert_equal "now/index.html", resolved("/now")
    assert_equal "now/index.html", resolved("/now/")
    assert_equal "now/index.html", resolved("/now/index.html")
    assert_equal "with space.html", resolved("/with%20space")
    assert_equal "about.html", resolved("/about?x=1#y")
  end

  test "misses" do
    assert_nil resolved("/missing")
    assert_nil resolved("/about/")
    assert_nil resolved("/assets")
  end

  test "never escapes root" do
    outside = tmp_output.join("../kiln-outside-#{SecureRandom.hex(4)}.html")
    outside.write("secret")
    File.symlink(outside, tmp_output.join("link.html"))

    assert_nil resolved("/../#{outside.basename}")
    assert_nil resolved("/%2e%2e/#{outside.basename}")
    assert_nil resolved("/link")
    assert_nil resolved("/about%00")
  ensure
    FileUtils.rm_f(outside)
  end
end
