require "test_helper"
require "kiln/content"

class Kiln::Content::MarkdownTest < Kiln::TestCase
  FIXTURES = Pathname(__dir__).join("fixtures")

  teardown { Kiln::Content.source_positions = nil }

  test "renders markdown with tables, autolinks, strikethrough and heading ids" do
    html = Kiln::Content::Markdown.render("# Hi there\n\n| a |\n|---|\n| 1 |\n\n~~x~~ https://example.com\n")

    assert_includes html, %(<h1 id="hi-there">Hi there</h1>)
    assert_includes html, "<table>\n<thead>\n<tr>\n<th>a</th>"
    assert_includes html, "<del>x</del>"
    assert_includes html, %(<a href="https://example.com">https://example.com</a>)
  end

  test "a line break inside a paragraph is a soft break, and two trailing spaces still break the line" do
    assert_equal "<p>one\ntwo</p>\n", Kiln::Content::Markdown.render("one\ntwo\n")
    assert_equal "<p>one<br />\ntwo</p>\n", Kiln::Content::Markdown.render("one  \ntwo\n")
  end

  test "render_inline drops the paragraph around a single paragraph" do
    assert_equal "Hello <em>there</em>", Kiln::Content::Markdown.render_inline("Hello *there*\n")
    assert_equal "", Kiln::Content::Markdown.render_inline("")
    assert_equal "<p>one</p>\n<p>two</p>\n", Kiln::Content::Markdown.render_inline("one\n\ntwo\n")
    assert_equal "<ul>\n<li>item</li>\n</ul>\n", Kiln::Content::Markdown.render_inline("- item\n")
  end

  test "highlights fenced code with CSS classes and no inline styles" do
    html = Kiln::Content::Markdown.render("```ruby\ndef hi = 1\n```\n")

    assert_includes html, %(<pre class="highlight ruby" data-language="ruby"><code>)
    assert_includes html, %(<span class="k">def</span>)
    assert_not_includes html, "style="
  end

  test "unknown or missing languages fall back to plain text and keep the fence's language" do
    assert_includes Kiln::Content::Markdown.render("```nope\n<b>\n```\n"), %(<pre class="highlight plaintext" data-language="nope"><code>&lt;b&gt;)
    assert_includes Kiln::Content::Markdown.render("```\nx\n```\n"), %(<pre class="highlight plaintext"><code>)
    assert_includes Kiln::Content::Markdown.render("```a\"b x\nx\n```\n"), %(data-language="a&quot;b")
  end

  test ".md views render through the layout" do
    html = view.render(template: "pages/about", layout: "layouts/simple")

    assert_match %r{\A<main><h1 id="about-me">About me</h1>}, html
    assert_includes html, %(<span class="k">def</span>)
    assert_includes html, "<table>"
  end

  test ".md.erb views run ERB, then Markdown" do
    html = view.render(template: "pages/erb", layout: "layouts/simple", locals: { title: "From ERB" })

    assert_includes html, %(<h1 id="from-erb">From ERB</h1>)
    assert_includes html, "<li>item 0</li>\n<li>item 1</li>"
    assert_includes html, "&lt;script&gt;"
    assert_not_includes html, "<script>"
  end

  test "raw HTML passes through" do
    assert_includes Kiln::Content::Markdown.render("<div class=\"note\">hi</div>\n"), %(<div class="note">hi</div>)
  end

  test "source positions are off by default, also in development with Tensaku loaded" do
    Object.const_set(:Tensaku, Module.new)
    Rails.env = "development"
    assert_not Kiln::Content.source_positions
    assert_not_includes view.render(template: "pages/about"), "data-md-source"
  ensure
    Object.send(:remove_const, :Tensaku)
    Rails.env = "test"
  end

  test ".md views mark each block with its source position" do
    Kiln::Content.source_positions = true
    html = view.render(template: "pages/about")
    path = FIXTURES.join("views/pages/about.html.md").relative_path_from(Rails.root)

    assert_includes html, %(<h1 id="about-me" data-md-source="#{path}:1:1-1:10">)
    assert_includes html, %(<p data-md-source="#{path}:3:1-3:12">)
    assert_includes html, %(<pre class="highlight ruby" data-language="ruby" data-md-source="#{path}:5:1-7:3"><code>)
    assert_includes html, %(<table data-md-source="#{path}:9:1-11:9">)
    assert_not_includes html, "data-sourcepos"
  end

  test "source position paths are relative to Rails.root" do
    html = Kiln::Content::Markdown.render("\nHi\n", path: Rails.root.join("content/a.md"), line_offset: 3)
    assert_equal %(<p data-md-source="content/a.md:5:1-5:2">Hi</p>\n), html
  end

  test "only block elements carry source positions" do
    html = Kiln::Content::Markdown.render("A [link](/x) and *em*\n", path: Rails.root.join("content/a.md"))
    assert_equal %(<p data-md-source="content/a.md:1:1-1:21">A <a href="/x">link</a> and <em>em</em></p>\n), html
  end

  test ".md.erb views get no source positions" do
    Kiln::Content.source_positions = true
    html = view.render(template: "pages/erb", locals: { title: "From ERB" })

    assert_includes html, %(<h1 id="from-erb">)
    assert_not_includes html, "data-md-source"
  end

  test "no source positions while building" do
    Kiln::Content.source_positions = true
    Kiln.building! do
      assert_not Kiln::Content.source_positions
      assert_not_includes view.render(template: "pages/about"), "data-md-source"
    end
  end

  test "ERB errors keep the template line number" do
    File.write(tmp_output.join("broken.html.md.erb"), "# Title\n\n<%= nope %>\n")
    view = ActionView::Base.with_empty_template_cache.with_view_paths([ tmp_output.to_s ])

    error = assert_raises(ActionView::Template::Error) { view.render(template: "broken") }
    assert_equal 3, error.line_number.to_i
  end

  private
    def view
      ActionView::Base.with_empty_template_cache.with_view_paths([ FIXTURES.join("views").to_s ])
    end
end
