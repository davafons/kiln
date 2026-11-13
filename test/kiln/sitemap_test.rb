require "test_helper"

class Kiln::SitemapTest < Kiln::TestCase
  def writer = Kiln::Writer.new(tmp_output, mode: :directory, report: Kiln::Report.new)

  def response(headers = {}, content_type: "text/html; charset=utf-8")
    Kiln::Response.new(path: "/", status: 200, headers: { "content-type" => content_type }.merge(headers), body: "")
  end

  test "noindex from the x-robots-tag header" do
    assert Kiln::Sitemap.noindex?(response({ "x-robots-tag" => "noindex, nofollow" }), "<p>hi</p>")
  end

  test "noindex from the robots meta tag" do
    assert Kiln::Sitemap.noindex?(response, %(<head><meta name="Robots" content="NOINDEX"></head>))
    assert_not Kiln::Sitemap.noindex?(response, %(<head><meta name="description" content="noindex"></head>))
    assert_not Kiln::Sitemap.noindex?(response, "<p>hi</p>")
  end

  test "non-HTML is never noindex" do
    assert_not Kiln::Sitemap.noindex?(response({ "x-robots-tag" => "noindex" }, content_type: "application/json"), "{}")
  end

  test "writes indexable HTML pages" do
    manifest = Kiln::Manifest.new
    manifest.add("/", file: "index.html", body: "x", content_type: "text/html")
    manifest.add("/now", file: "now/index.html", body: "x", content_type: "text/html")
    manifest.add("/later", file: "later.html", body: "x", content_type: "text/html")
    manifest.add("/hidden", file: "hidden/index.html", body: "x", content_type: "text/html", noindex: true)
    manifest.add("/feed.xml", file: "feed.xml", body: "x", content_type: "application/xml")

    assert_equal "sitemap.xml", Kiln::Sitemap.new(manifest, url: "https://example.com/").write(writer)
    assert_equal <<~XML, tmp_output.join("sitemap.xml").read
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://example.com/</loc></url>
        <url><loc>https://example.com/later</loc></url>
        <url><loc>https://example.com/now/</loc></url>
      </urlset>
    XML
  end
end
