require "test_helper"

class Kiln::WriterTest < Kiln::TestCase
  test "writes HTML pages as .html files" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "index.html", writer.file_for("/", "text/html")
    assert_equal "now.html", writer.file_for("/now", "text/html")
    assert_equal "now.html", writer.file_for("/now/", "text/html")
    assert_equal "blog/2024/post.html", writer.file_for("/blog/2024/post", "text/html; charset=utf-8")
  end

  test "an HTML page whose last segment has a dot still gets .html" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "posts/v1.2.html", writer.file_for("/posts/v1.2", "text/html")
    assert_equal "posts/v1.2.html", writer.file_for("/posts/v1.2/", "text/html")
  end

  test "keeps paths that have an extension" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "feed.xml", writer.file_for("/feed.xml", "application/xml")
    assert_equal "health.json", writer.file_for("/health.json", "application/json")
    assert_equal "ping.txt", writer.file_for("/ping.txt", "text/plain")
    assert_equal "components.html", writer.file_for("/components.html", "text/html")
  end

  test "adds an extension from the MIME type" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "api/status.json", writer.file_for("/api/status", "application/json")
    assert_equal "api/status.json", writer.file_for("/api/status", "application/json; charset=utf-8")
    assert_equal "robots.txt", writer.file_for("/robots", "text/plain")
    assert_equal "blob", writer.file_for("/blob", "application/x-unknown")
    assert_equal "blob", writer.file_for("/blob", nil)
  end

  test "percent-decodes segments" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "tags/日本.html", writer.file_for("/tags/%E6%97%A5%E6%9C%AC", "text/html")
    assert_equal "a+b.html", writer.file_for("/a+b", "text/html")
  end

  test "rejects traversal" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_raises(Kiln::Error) { writer.file_for("/../etc/passwd", "text/html") }
    assert_raises(Kiln::Error) { writer.file_for("/a/%2E%2E/%2E%2E/b", "text/html") }
    assert_raises(Kiln::Error) { writer.file_for("/a%2F..%2Fb", "text/html") }
    assert_raises(Kiln::Error) { writer.file_for("/%E6%97", "text/html") }
    assert_raises(Kiln::Error) { writer.write_file("../outside.txt", "x") }
    assert_raises(Kiln::Error) { writer.write_file("/etc/outside.txt", "x") }
  end

  test "writes files and creates directories" do
    writer = Kiln::Writer.new(tmp_output, report: Kiln::Report.new)

    assert_equal "now.html", writer.write("/now", "text/html", "<p>now</p>")
    assert_equal "<p>now</p>", tmp_output.join("now.html").read
    assert_equal "CNAME", writer.write_file("CNAME", "example.com\n")
    assert_equal "example.com\n", tmp_output.join("CNAME").read
  end

  test "records written files in the report" do
    report = Kiln::Report.new
    writer = Kiln::Writer.new(tmp_output, report:)
    2.times { writer.write_file("CNAME", "example.com\n") }

    assert_equal [ "CNAME" ], report.written
  end

  test "writes binary bodies unchanged" do
    bytes = "\x89PNG\r\n\x1A\n\xFF\x00".b
    Kiln::Writer.new(tmp_output, report: Kiln::Report.new).write("/logo.png", "image/png", bytes)

    assert_equal bytes, tmp_output.join("logo.png").binread
  end

  test "copies public/ without overwriting rendered files" do
    public_dir = tmp_output.join("public")
    out = tmp_output.join("out")
    public_dir.join("assets").mkpath
    public_dir.join(".well-known").mkpath
    public_dir.join("assets/old.css").write("x")
    public_dir.join(".well-known/security.txt").write("hi")
    public_dir.join("icon.svg").write("<svg/>")
    public_dir.join("404.html").write("static")
    out.mkpath
    out.join("404.html").write("rendered")
    report = Kiln::Report.new

    Kiln::Writer.new(out, report:).copy_public(public_dir)

    assert_equal "<svg/>", out.join("icon.svg").read
    assert_equal "hi", out.join(".well-known/security.txt").read
    assert_equal "rendered", out.join("404.html").read
    assert_not out.join("assets").exist?
    assert_equal %w[.well-known/security.txt icon.svg], report.written.sort
    assert_equal [ [ :write, "/404.html" ] ], report.warnings.map { [ it.kind, it.path ] }
  end
end
