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

  test "serves each file at one URL" do
    assert_equal "index.html", resolved("/")
    assert_equal "index.html", resolved("")
    assert_equal "assets/app.css", resolved("/assets/app.css")
    assert_equal "about.html", resolved("/about")
    assert_equal "now/index.html", resolved("/now/")
    assert_equal "with space.html", resolved("/with%20space")
    assert_equal "about.html", resolved("/about?x=1#y")
  end

  test "other spellings of a page redirect to the URL it is served at" do
    { "/about/" => "/about", "/about//" => "/about", "/about.html" => "/about", "/with%20space/" => "/with%20space",
      "/now" => "/now/", "/now/index.html" => "/now/", "/index.html" => "/" }.each do |path, location|
      assert_nil resolved(path), path
      assert_equal location, @resolver.redirect(path), path
    end
  end

  test "misses" do
    %w[/missing /missing/ /assets /assets/ /missing.html /.html /about.html/].each do |path|
      assert_nil resolved(path), path
      assert_nil @resolver.redirect(path), path
    end
  end

  test "never escapes root" do
    outside = tmp_output.join("../kiln-outside-#{SecureRandom.hex(4)}.html")
    outside.write("secret")
    File.symlink(outside, tmp_output.join("link.html"))

    assert_nil resolved("/../#{outside.basename}")
    assert_nil resolved("/%2e%2e/#{outside.basename}")
    assert_nil resolved("/link")
    assert_nil @resolver.redirect("/link/")
    assert_nil resolved("/about%00")
  ensure
    FileUtils.rm_f(outside)
  end
end
