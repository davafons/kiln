require "test_helper"
require "kiln/content"

class Kiln::Content::MarkdownTest < Kiln::TestCase
  FIXTURES = Pathname(__dir__).join("fixtures")

  test "renders markdown with tables, autolinks, strikethrough and heading ids" do
    html = Kiln::Content::Markdown.render("# Hi there\n\n| a |\n|---|\n| 1 |\n\n~~x~~ https://example.com\n")

    assert_includes html, %(<h1 id="hi-there">Hi there</h1>)
    assert_includes html, "<table>"
    assert_includes html, "<del>x</del>"
    assert_includes html, %(<a href="https://example.com">https://example.com</a>)
  end

  test "highlights fenced code with CSS classes and no inline styles" do
    html = Kiln::Content::Markdown.render("```ruby\ndef hi = 1\n```\n")

    assert_includes html, %(<pre class="highlight ruby"><code>)
    assert_includes html, %(<span class="k">def</span>)
    assert_not_includes html, "style="
  end

  test "unknown or missing languages fall back to plain text" do
    assert_includes Kiln::Content::Markdown.render("```nope\n<b>\n```\n"), %(<pre class="highlight plaintext"><code>&lt;b&gt;)
    assert_includes Kiln::Content::Markdown.render("```\nx\n```\n"), %(<pre class="highlight plaintext">)
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
