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
      posts/second-post/index.html private/index.html feed.xml health.json ping.txt 404.html
      icon.svg _redirects sitemap.xml kiln-manifest.json
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

  test "redirects, sitemap and manifest" do
    build
    assert_equal "/old-about /about 301\n", read("_redirects")

    sitemap = read("sitemap.xml")
    assert_includes sitemap, "<loc>https://example.com/posts/hello-world</loc>"
    refute_includes sitemap, "/private", "noindex pages stay out of the sitemap"

    manifest = JSON.parse(read("kiln-manifest.json"))
    assert_equal "posts/hello-world/index.html", manifest["/posts/hello-world"]["file"]
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
    config = Kiln.config.dup
    config.copy_public = false
    report = build(config:).report

    broken = report.errors.select { it.kind == :broken_link }
    assert_includes broken.map(&:message), "/icon.svg", "the layout links to a public/ file that was not copied"
  end

  test "hooks receive the build context, and hook errors are reported" do
    seen = nil
    config = Kiln.config.dup
    config.instance_variable_set(:@before_build_hooks, [ ->(context) { seen = context } ])
    config.instance_variable_set(:@after_build_hooks, [ ->(_) { raise "boom" } ])

    report = build(config:).report
    assert_equal tmp_output, seen.output
    assert_equal [ "RuntimeError: boom" ], report.errors.select { it.kind == :hook }.map { it.message.split(" (").first }
  end

  test "reports pages changed since the previous build" do
    build
    second = build
    assert_equal({ added: [], removed: [], changed: [] }, second.changes)
  end

  test "Kiln.building? and the build cache only live during a build" do
    inside = nil
    config = Kiln.config.dup
    config.instance_variable_set(:@before_build_hooks, [ ->(_) { inside = Kiln.building?; Kiln.build_cache.write(:x, 1) } ])
    build(config:)

    assert inside
    refute Kiln.building?
    assert_nil Kiln.build_cache.read(:x)
  end

  test "refuses to wipe the app" do
    assert_raises(Kiln::Error) { Kiln::Build.new(output: Rails.root).run }
    assert_raises(Kiln::Error) { Kiln::Build.new(output: Rails.root.join("..")).run }
  end
end
