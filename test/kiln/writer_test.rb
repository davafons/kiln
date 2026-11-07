require "test_helper"

class Kiln::WriterTest < Kiln::TestCase
  test "maps paths in directory mode" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_equal "index.html", writer.file_for("/", "text/html")
    assert_equal "now/index.html", writer.file_for("/now", "text/html")
    assert_equal "now/index.html", writer.file_for("/now/", "text/html")
    assert_equal "blog/2024/post/index.html", writer.file_for("/blog/2024/post", "text/html")
  end

  test "maps paths in file mode" do
    writer = Kiln::Writer.new(tmp_output, mode: :file)

    assert_equal "index.html", writer.file_for("/", "text/html")
    assert_equal "now.html", writer.file_for("/now", "text/html")
    assert_equal "now.html", writer.file_for("/now/", "text/html")
    assert_equal "components/button.html", writer.file_for("/components/button", "text/html")
  end

  test "keeps paths that have an extension" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_equal "feed.xml", writer.file_for("/feed.xml", "application/xml")
    assert_equal "health.json", writer.file_for("/health.json", "application/json")
    assert_equal "ping.txt", writer.file_for("/ping.txt", "text/plain")
    assert_equal "components.html", writer.file_for("/components.html", "text/html")
  end

  test "adds an extension from the MIME type" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_equal "api/status.json", writer.file_for("/api/status", "application/json")
    assert_equal "api/status.json", writer.file_for("/api/status", "application/json; charset=utf-8")
    assert_equal "robots.txt", writer.file_for("/robots", "text/plain")
    assert_equal "blob", writer.file_for("/blob", "application/x-unknown")
    assert_equal "blob", writer.file_for("/blob", nil)
  end

  test "percent-decodes segments" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_equal "tags/日本/index.html", writer.file_for("/tags/%E6%97%A5%E6%9C%AC", "text/html")
    assert_equal "a+b/index.html", writer.file_for("/a+b", "text/html")
  end

  test "rejects traversal" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_raises(Kiln::Error) { writer.file_for("/../etc/passwd", "text/html") }
    assert_raises(Kiln::Error) { writer.file_for("/a/%2E%2E/%2E%2E/b", "text/html") }
    assert_raises(Kiln::Error) { writer.file_for("/a%2F..%2Fb", "text/html") }
    assert_raises(Kiln::Error) { writer.write_file("../outside.txt", "x") }
    assert_raises(Kiln::Error) { writer.write_file("/etc/outside.txt", "x") }
  end

  test "rejects an unknown mode" do
    assert_raises(Kiln::Error) { Kiln::Writer.new(tmp_output, mode: :flat) }
  end

  test "writes files and creates directories" do
    writer = Kiln::Writer.new(tmp_output, mode: :directory)

    assert_equal "now/index.html", writer.write("/now", "text/html", "<p>now</p>")
    assert_equal "<p>now</p>", tmp_output.join("now/index.html").read
    assert_equal "CNAME", writer.write_file("CNAME", "example.com\n")
    assert_equal "example.com\n", tmp_output.join("CNAME").read
  end

  test "writes binary bodies unchanged" do
    bytes = "\x89PNG\r\n\x1A\n\xFF\x00".b
    Kiln::Writer.new(tmp_output, mode: :directory).write("/logo.png", "image/png", bytes)

    assert_equal bytes, tmp_output.join("logo.png").binread
  end
end
