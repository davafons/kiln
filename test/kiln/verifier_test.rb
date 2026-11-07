require "test_helper"

class Kiln::VerifierTest < Kiln::TestCase
  def site(files, skip = [])
    files.each do |file, body|
      tmp_output.join(file).dirname.mkpath
      tmp_output.join(file).write(body)
    end
    config = Kiln::Configuration.new.tap { it.url = "https://example.com"; it.verify_skip = skip }
    Kiln::Verifier.new(tmp_output, config:).verify(Kiln::Report.new)
  end

  def errors(report) = report.errors.map { [ it.kind, it.message, it.path ] }

  test "passes a consistent site" do
    report = site(
      "index.html" => <<~HTML,
        <link rel="stylesheet" href="/assets/app.css">
        <link rel="canonical" href="https://example.com/">
        <a href="now/">Now</a> <a href="/now#today">Today</a> <a href="#top">Top</a> <a href="#main">Main</a>
        <a href="mailto:me@example.com">Mail</a> <a href="tel:123">Call</a> <a href="javascript:void(0)">JS</a>
        <a href="https://other.com/missing">Out</a> <a href="//cdn.other.com/x.js">CDN</a>
        <img src="data:image/png;base64,AAAA" srcset="/assets/logo.svg 1x, /assets/logo.svg 2x">
        <a href="/old">Old</a> <a href="/about?ref=home">About</a>
        <main id="main"></main>
        <script type="importmap">{"imports": {"app": "/assets/app.js"}, "scopes": {"/assets/": {"x": "/assets/app.js"}}}</script>
      HTML
      "now/index.html" => %(<h2 id="today">Today</h2><a href="../">Home</a><a name="legacy"></a><a href="#legacy">L</a>),
      "about.html" => %(<a href="/">Home</a>),
      "assets/app.css" => "",
      "assets/app.js" => "",
      "assets/logo.svg" => "",
      "_redirects" => "/old /now 301\n"
    )

    assert_empty errors(report)
  end

  test "reports broken links, missing anchors and importmap entries once each" do
    report = site(
      "index.html" => <<~HTML,
        <a href="/missing">1</a> <a href="/missing">again</a>
        <a href="https://example.com/gone">2</a>
        <a href="#nope">3</a> <a href="/about#nope">4</a>
        <img srcset="/assets/a.png 1x, /assets/b.png 2x">
        <script type="importmap">{"imports": {"app": "/assets/app.js", "ext": "https://cdn.other.com/x.js"}}</script>
      HTML
      "about.html" => %(<a href="sub">relative</a>),
      "bad/index.html" => %(<script type="importmap">{nope</script>)
    )

    assert_equal [
      [ :broken_link, "/missing", "/" ],
      [ :broken_link, "https://example.com/gone", "/" ],
      [ :missing_anchor, "#nope", "/" ],
      [ :missing_anchor, "/about#nope", "/" ],
      [ :broken_link, "/assets/a.png", "/" ],
      [ :broken_link, "/assets/b.png", "/" ],
      [ :importmap, "/assets/app.js", "/" ],
      [ :broken_link, "sub", "/about" ],
      [ :importmap, "invalid importmap JSON", "/bad/" ]
    ].sort, errors(report).sort
  end

  test "ignores links inside verify_skip selectors" do
    report = site({
      "index.html" => <<~HTML
        <div data-example-preview><nav><a href="#general">General</a><a href="/missing">Demo</a></nav></div>
        <a href="#real">Checked</a>
      HTML
    }, [ "[data-example-preview]" ])

    assert_equal [ [ :missing_anchor, "#real", "/" ] ], errors(report)
  end
end
