require "test_helper"

class Kiln::Processors::AbsoluteUrlsTest < Kiln::TestCase
  test "makes root-relative image URLs absolute" do
    html = <<~HTML
      <meta property="og:image" content="/og.png">
      <meta name="twitter:image" content="/tw.png">
      <img alt="Logo" src="/assets/logo.png" srcset="/a.png 1x, /b.png 2x,/c.png 3x">
    HTML

    assert_equal <<~HTML, call(html)
      <meta property="og:image" content="https://example.com/og.png">
      <meta name="twitter:image" content="https://example.com/tw.png">
      <img alt="Logo" src="https://example.com/assets/logo.png" srcset="https://example.com/a.png 1x, https://example.com/b.png 2x,https://example.com/c.png 3x">
    HTML
  end

  test "leaves absolute, protocol-relative and relative URLs alone" do
    html = %(<img src="https://cdn.test/a.png"><img src="//cdn.test/b.png"><img src="c.png" data-src="/d.png"><meta property="og:title" content="/t">)

    assert_equal html, call(html)
  end

  test "leaves links and other tags alone" do
    html = %(<a href="/about">About</a><script src="/app.js"></script>)

    assert_equal html, call(html)
  end

  test "requires config.url" do
    assert_raises(Kiln::Error) { call("<img src=\"/a.png\">", url: nil) }
  end

  private
    def call(html, url: "https://example.com/")
      config = Kiln::Configuration.new.tap { it.url = url }
      Kiln::Processors::AbsoluteUrls.call(html, Kiln::Processors::Context.new(path: "/", config:, response: nil))
    end
end
