require "test_helper"
require "kiln/content"

class Kiln::Content::FileTest < Kiln::TestCase
  setup do
    Kiln::Content.reset!
    @dir = Pathname(Dir.mktmpdir)
    @path = @dir.join("CONTRIBUTING.md")
    @path.write("---\ntitle: Contribute\n---\n# Contribute\n\nRead this.\n")
  end

  teardown do
    Kiln::Content.reset!
    FileUtils.rm_rf(@dir)
  end

  test "reads one Markdown file as an entry" do
    entry = Kiln::Content.file(@path)

    assert_equal "Contribute", entry.title
    assert_equal "CONTRIBUTING", entry.slug
    assert_nil entry.collection
    assert_equal "# Contribute\n\nRead this.\n", entry.body
    assert_includes entry.html, %(<h1 id="contribute">Contribute</h1>)
  end

  test "reads the file again when it changes" do
    first = Kiln::Content.file(@path)
    assert_same first, Kiln::Content.file(@path)

    @path.write("# Changed\n")
    File.utime(Time.now + 5, Time.now + 5, @path)
    assert_includes Kiln::Content.file(@path).html, "Changed"
  end

  test "source positions count the frontmatter lines" do
    Kiln::Content.source_positions = true
    html = Kiln::Content.file(@path).html
    relative = @path.relative_path_from(Rails.root)

    assert_includes html, %(<p data-tensaku-md="#{relative}:6:1-6:10">Read this.</p>)
  end
end
