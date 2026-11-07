require "test_helper"

class Kiln::Processors::ExternalLinksTest < Kiln::TestCase
  test "opens links to other hosts in a new tab" do
    assert_equal %(<a href="https://github.com/x" target="_blank" rel="noopener">GitHub</a>),
      call(%(<a href="https://github.com/x">GitHub</a>))
    assert_equal %(<a class="link" href="http://other.test" target="_blank" rel="noopener">x</a>),
      call(%(<a class="link" href="http://other.test">x</a>))
  end

  test "merges with existing rel and target" do
    assert_equal %(<a href="https://other.test" rel="me noopener" target="_blank">x</a>),
      call(%(<a href="https://other.test" rel="me">x</a>))
    assert_equal %(<a href="https://other.test" target="_self" rel="noopener">x</a>),
      call(%(<a href="https://other.test" target="_self">x</a>))
    assert_equal %(<a href="https://other.test" rel="noopener" target="_blank">x</a>),
      call(%(<a href="https://other.test" rel="noopener">x</a>))
  end

  test "leaves internal and non-http links alone" do
    html = %(<a href="https://example.com/about">a</a><a href="https://EXAMPLE.com">b</a><a href="/x">c</a>) +
      %(<a href="mailto:me@other.test">d</a><a data-href="https://other.test" href="#top">e</a><link href="https://other.test/x.css">)

    assert_equal html, call(html)
  end

  private
    def call(html)
      config = Kiln::Configuration.new.tap { it.url = "https://example.com" }
      Kiln::Processors::ExternalLinks.call(html, Kiln::Processors::Context.new(path: "/", config:, response: nil))
    end
end
