require "test_helper"

class Kiln::RedirectsTest < Kiln::TestCase
  class FakeWriter
    def initialize(output) = @output = output
    def file_for(path, _content_type) = path == "/" ? "index.html" : "#{path.delete_prefix("/")}/index.html"

    def write_file(relative, body)
      @output.join(relative).dirname.mkpath
      @output.join(relative).write(body)
      relative
    end
  end

  def redirects(mode)
    entries = [
      Kiln::Redirects::Entry.new(from: "/old", to: "https://example.com/new?a=1#top", status: 301),
      Kiln::Redirects::Entry.new(from: "/out", to: "https://other.com/", status: 302)
    ]
    Kiln::Redirects.new(entries, mode:, writer: FakeWriter.new(tmp_output), host: "example.com")
  end

  test "file mode writes _redirects with same-host locations made relative" do
    assert_equal %w[_redirects], redirects(:file).write(tmp_output)
    assert_equal "/old /new?a=1#top 301\n/out https://other.com/ 302\n", tmp_output.join("_redirects").read
  end

  test "meta_refresh mode writes HTML pages" do
    assert_equal %w[old/index.html out/index.html], redirects(:meta_refresh).write(tmp_output)

    html = tmp_output.join("old/index.html").read
    assert_includes html, %(<meta http-equiv="refresh" content="0; url=/new?a=1#top">)
    assert_includes html, %(<link rel="canonical" href="/new?a=1#top">)
    assert_includes html, %(<a href="/new?a=1#top">)
    assert_not tmp_output.join("_redirects").exist?
  end

  test "both mode writes everything" do
    assert_equal %w[_redirects old/index.html out/index.html], redirects(:both).write(tmp_output)
  end

  test "load reads a _redirects file" do
    tmp_output.join("_redirects").write("# comment\n\n/a /b 301\n/c /d\n")

    assert_equal [
      Kiln::Redirects::Entry.new(from: "/a", to: "/b", status: 301),
      Kiln::Redirects::Entry.new(from: "/c", to: "/d", status: 302)
    ], Kiln::Redirects.load(tmp_output.join("_redirects"))
    assert_equal [], Kiln::Redirects.load(tmp_output.join("missing"))
  end

  test "keeps hand-written rules from a copied public/_redirects first" do
    tmp_output.join("_redirects").write("/docs/* /guide/:splat 301\n")
    entries = [ Kiln::Redirects::Entry.new(from: "/old", to: "https://localhost/new", status: 301) ]
    Kiln::Redirects.new(entries, mode: :file, writer: nil, host: "localhost").write(tmp_output)

    assert_equal "/docs/* /guide/:splat 301\n/old /new 301\n", tmp_output.join("_redirects").read
  end
end
