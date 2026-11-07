require "test_helper"

class Kiln::ProcessorsTest < Kiln::TestCase
  HTML = %(<head><meta name="csrf-token" content="t"></head><img src="/a.png"><a href="https://other.test">x</a>)

  setup { @config = Kiln::Configuration.new.tap { it.url = "https://example.com" } }

  test "strips CSRF by default and leaves optional processors off" do
    assert_equal %(<head></head><img src="/a.png"><a href="https://other.test">x</a>), apply(HTML)
  end

  test "runs optional built-ins when enabled" do
    @config.absolute_urls = true
    @config.external_links = true

    assert_equal %(<head></head><img src="https://example.com/a.png"><a href="https://other.test" target="_blank" rel="noopener">x</a>), apply(HTML)
  end

  test "runs custom processors last, in order, with the context" do
    seen = []
    @config.processors = [
      ->(html, context) { seen << [ html, context.path ]; html.upcase },
      ->(html, _context) { "#{html}!" }
    ]

    assert_equal %(<HEAD></HEAD><IMG SRC="/A.PNG"><A HREF="HTTPS://OTHER.TEST">X</A>!), apply(HTML)
    assert_equal [ [ %(<head></head><img src="/a.png"><a href="https://other.test">x</a>), "/page" ] ], seen
  end

  test "rejects a processor that does not return a String" do
    @config.processors = [ ->(_html, _context) { nil } ]

    error = assert_raises(Kiln::Error) { apply(HTML) }
    assert_match "returned NilClass for /page", error.message
  end

  test "returns the input unchanged when nothing matches" do
    @config.absolute_urls = true
    @config.external_links = true
    html = File.read(Rails.root.join("app/views/layouts/application.html.erb"))

    assert_equal html, apply(html)
  end

  private
    def apply(html)
      Kiln::Processors.apply(html, Kiln::Processors::Context.new(path: "/page", config: @config, response: nil))
    end
end
