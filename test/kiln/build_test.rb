require "test_helper"

class Kiln::BuildTest < Kiln::TestCase
  def build(pages: Kiln.pages, config: Kiln.config)
    Kiln::Build.new(output: tmp_output, pages:, config:).tap(&:run)
  end

  def read(file) = tmp_output.join(file).read

  test "builds the dummy app" do
    result = build
    assert result.report.success?, result.report.to_s

    %w[
      index.html about/index.html guide/index.html posts/index.html posts/hello-world/index.html
      posts/second-post/index.html private/index.html contact/index.html es/contact/index.html
      ja/contact/index.html feed.xml health.json ping.txt 404.html
      icon.svg _redirects sitemap.xml
    ].each { assert tmp_output.join(it).file?, "expected #{it}" }

    refute tmp_output.join("search").exist?, "skipped route must not be built"
    refute tmp_output.join("not-found").exist?, "404 route is only written as 404.html"
    refute tmp_output.join("up").exist?
  end

  test "pages render the way the browser sees them" do
    build
    home = read("index.html")
    assert_includes home, "<h1>Home</h1>"
    refute_includes home, "dev-panel", "Kiln.building? hides dev-only markup"
    assert_includes read("guide/index.html"), "there are 2 posts"
    assert_includes read("404.html"), "Not found"
    assert_equal({ "status" => "ok", "posts" => 2 }, JSON.parse(read("health.json")))
    assert_equal "pong", read("ping.txt")
  end

  test "writes referenced assets with their digests" do
    build
    css = Dir[tmp_output.join("assets/application-*.css")].first
    assert css, "stylesheet exported"
    pattern = File.read(css)[%r{/assets/pattern-\w+\.svg}]
    assert tmp_output.join(pattern.delete_prefix("/")).file?, "CSS url() asset exported"
    assert Dir[tmp_output.join("assets/controllers/hello_controller-*.js")].any?, "importmap modules exported"
  end

  test "a precompiling build exports assets without touching public/assets" do
    assets = dummy_app.config.assets
    original = assets.slice(:server, :output_path, :manifest_path)
    assets.server = false
    public_assets = nil
    rendering = ->(html) { public_assets = Rails.root.join("public/assets").exist?; html }

    replace_method(Kiln::Processors::StripCSRF, :call, rendering) { assert build.report.success? }
    assert_equal false, public_assets
    assert Dir[tmp_output.join("assets/application-*.css")].any?
    assert_equal original, assets.slice(:server, :output_path, :manifest_path).merge(server: original[:server])
  ensure
    assets.merge!(original)
  end

  test "redirects, sitemap and manifest" do
    result = build
    assert_equal "/old-about /about 301\n", read("_redirects")

    sitemap = read("sitemap.xml")
    assert_includes sitemap, "<loc>https://example.com/posts/hello-world</loc>"
    refute_includes sitemap, "/private", "noindex pages stay out of the sitemap"

    assert_equal "posts/hello-world/index.html", result.manifest.entries["/posts/hello-world"][:file]
    refute tmp_output.join("kiln-manifest.json").exist?, "the manifest is build state, not part of the site"
  end

  test "file mode" do
    config = Kiln.config.dup
    config.paths = :file
    assert build(config:).report.success?
    assert tmp_output.join("about.html").file?
    assert tmp_output.join("posts/hello-world.html").file?
  end

  test "uncovered routes fail the build and name the route" do
    pages = Kiln::Pages.new.tap { it.skip :search }
    report = build(pages:).report

    assert report.failure?
    entry = report.errors.find { it.kind == :uncovered_route }
    assert_match "post", entry.message
  end

  test "collects every render error instead of stopping at the first" do
    pages = Kiln::Pages.new.tap do
      it.params :post, -> { [ { slug: "missing-one" }, { slug: "hello-world" }, { slug: "missing-two" } ] }
      it.skip :search
    end
    result = build(pages:)

    render_errors = result.report.errors.select { it.kind == :render }
    assert_equal %w[/posts/missing-one /posts/missing-two], render_errors.map(&:path)
    assert_match "RoutingError", render_errors.first.message
    assert tmp_output.join("posts/hello-world/index.html").file?, "good pages are still written"
  end

  test "reports broken links found by the verifier" do
    report = Dir.mktmpdir do |dir|
      source = File.join(dir, "broken.html")
      File.write(source, %(<a href="/missing">Missing</a>))
      config = Kiln.config.dup
      config.files = { "broken.html" => source }
      build(config:).report
    end

    assert_equal [ [ "/missing", "/broken" ] ], report.errors.select { it.kind == :broken_link }.map { [ it.message, it.path ] }
  end

  test "reports pages changed since the previous build of the configured output" do
    config = Kiln.config.dup
    config.output = tmp_output.to_s
    build(config:)
    second = build(config:)

    assert_equal({ added: [], removed: [], changed: [] }, second.changes)
    assert Rails.root.join("tmp/kiln-manifest.json").file?
    assert_nil build.changes, "throwaway builds keep no manifest"
  end

  test "copies extra files that aren't routes" do
    config = Kiln.config.dup
    config.files = { "licenses/post.txt" => "app/models/post.rb", "missing.txt" => "nope.txt" }
    report = build(config:).report

    assert_equal Rails.root.join("app/models/post.rb").read, read("licenses/post.txt")
    assert_equal [ "/missing.txt" ], report.errors.select { it.kind == :write }.map(&:path)
  end

  test "writes CNAME from a string or from the url" do
    config = Kiln.config.dup
    config.cname = "docs.example.com"
    build(config:)
    assert_equal "docs.example.com\n", read("CNAME")

    config.cname = true
    build(config:)
    assert_equal "example.com\n", read("CNAME")

    config.url = nil
    assert_equal [ "/CNAME" ], build(config:).report.errors.map(&:path)
    assert_not tmp_output.join("sitemap.xml").exist?, "no sitemap without a url"
  end

  test "Kiln.building? and the build cache only live during a build" do
    inside = nil
    rendering = ->(html) { inside = Kiln.building?; Kiln.build_cache.fetch(:x) { 1 }; html }
    replace_method(Kiln::Processors::StripCSRF, :call, rendering) { build }

    assert inside
    refute Kiln.building?
    Kiln.building! { assert_equal 2, Kiln.build_cache.fetch(:x) { 2 } }
  end

  test "fails when editor source attributes reach the output" do
    herb = ->(html) { html.sub("<main>", '<main data-herb-source="app/views/x.html.erb:1:1">') }
    report = replace_method(Kiln::Processors::StripCSRF, :call, herb) { build.report }

    errors = report.errors.select { it.kind == :editor_markup }
    assert_equal 1, errors.size
    assert_match "data-herb-*", errors.first.message
    assert_match(/and \d+ more/, errors.first.message)
  end

  test "refuses to build with development middleware that injects markup" do
    app = Struct.new(:root, :middleware).new(Rails.root, [ Struct.new(:name).new("Hotwire::Spark::Middleware") ])
    error = assert_raises(Kiln::Error) { Kiln::Build.new(app:, output: tmp_output).run }
    assert_match "Hotwire::Spark::Middleware", error.message
  end

  test "gives an app without a secret_key_base a throwaway one" do
    config = Class.new do
      attr_writer :secret_key_base

      def secret_key_base = @secret_key_base || raise(ArgumentError, "Missing `secret_key_base`")
    end.new
    app = Struct.new(:root, :middleware, :config).new(Rails.root, [], config)
    build = Kiln::Build.new(app:, output: tmp_output)

    build.send(:ensure_secret_key_base)
    assert_equal 128, config.secret_key_base.size
  end

  test "refuses to wipe the app" do
    assert_raises(Kiln::Error) { Kiln::Build.new(output: Rails.root).run }
    assert_raises(Kiln::Error) { Kiln::Build.new(output: Rails.root.join("..")).run }
  end
end
