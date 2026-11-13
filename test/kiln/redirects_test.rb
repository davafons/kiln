require "test_helper"

class Kiln::RedirectsTest < Kiln::TestCase
  def writer = Kiln::Writer.new(tmp_output, mode: :directory, report: Kiln::Report.new)

  test "writes _redirects with same-host locations made relative" do
    entries = [
      Kiln::Redirects::Entry.new(from: "/old", to: "https://example.com/new?a=1#top", status: 301),
      Kiln::Redirects::Entry.new(from: "/out", to: "https://other.com/", status: 302)
    ]
    assert_equal "_redirects", Kiln::Redirects.new(entries, host: "example.com").write(writer)
    assert_equal "/old /new?a=1#top 301\n/out https://other.com/ 302\n", tmp_output.join("_redirects").read
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
    Kiln::Redirects.new(entries, host: "localhost").write(writer)

    assert_equal "/docs/* /guide/:splat 301\n/old /new 301\n", tmp_output.join("_redirects").read
  end
end
