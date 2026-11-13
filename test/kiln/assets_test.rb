require "test_helper"

class Kiln::AssetsTest < Kiln::TestCase
  # Stands in for Kiln::Renderer so these tests don't depend on it.
  class FakeRenderer
    def initialize(app) = @request = Rack::MockRequest.new(app)

    def get(path)
      response = @request.get(path, "HTTP_HOST" => "localhost")
      Kiln::Response.new(path:, status: response.status, headers: response.headers.transform_keys(&:downcase), body: response.body.b)
    end
  end

  setup do
    @renderer = FakeRenderer.new(dummy_app)
    @config = Kiln::Configuration.new
    @report = Kiln::Report.new
  end

  test "exports referenced assets, CSS url() targets and importmap modules" do
    render "/", "index.html"
    render "/about", "about/index.html"
    export

    assert_empty @report.errors
    assert written?(/\Aassets\/application-\h+\.css\z/)
    assert written?(/\Aassets\/logo-\h+\.svg\z/)
    assert written?(/\Aassets\/pattern-\h+\.svg\z/), "pattern.svg from CSS url() is exported"

    importmap = JSON.parse(Nokogiri::HTML(tmp_output.join("index.html").read).at_css('script[type="importmap"]').text)
    importmap["imports"].each_value do |url|
      assert tmp_output.join(url.delete_prefix("/")).file?, "#{url} is exported"
    end
    assert_equal @report.written.uniq, @report.written
  end

  test "writes binary-safe bodies" do
    page "logo.html", %(<img src="#{asset_url("logo.svg")}">)
    export

    path = asset_url("logo.svg")
    assert_equal @renderer.get(path).body, tmp_output.join(path.delete_prefix("/")).binread
  end

  test "follows srcset, relative CSS urls and @import, skipping data: and external URLs" do
    css = "@import \"other.css\";\na{background:url(\"../img/x.png\")}\nb{background:url(data:image/png;base64,AA)}\nc{background:url(https://cdn.example/x.png)}"
    renderer = StubRenderer.new(
      "/assets/one.png" => "png1", "/assets/two.png" => "png2",
      "/assets/css/main.css" => css, "/assets/css/other.css" => "x{}", "/assets/img/x.png" => "png3"
    )
    page "index.html", %(<img srcset="/assets/one.png 1x, /assets/two.png 2x"><link rel="stylesheet" href="/assets/css/main.css"><a href="/about">About</a>)
    export(renderer:)

    assert_empty @report.errors
    assert_equal %w[/assets/css/main.css /assets/css/other.css /assets/img/x.png /assets/one.png /assets/two.png], renderer.requested.sort
  end

  test "reports missing assets" do
    page "index.html", %(<script src="/assets/missing.js"></script>)
    export

    assert_equal [ [ :asset, "/assets/missing.js" ] ], @report.errors.map { [ it.kind, it.path ] }
  end

  test "reads importmap scopes" do
    renderer = StubRenderer.new("/assets/scoped.js" => "1")
    page "index.html", %(<script type="importmap">{"imports":{},"scopes":{"/x/":{"a":"/assets/scoped.js"}}}</script>)
    export(renderer:)

    assert_equal %w[/assets/scoped.js], renderer.requested
  end

  test "strips source maps from JS and CSS" do
    renderer = StubRenderer.new("/assets/a.js" => "a();\n//# sourceMappingURL=a.js.map\n")
    page "index.html", %(<script src="/assets/a.js"></script>)
    export(renderer:)
    assert_equal "a();\n", tmp_output.join("assets/a.js").read
  end

  test "copies public/ without overwriting rendered files" do
    public_dir = tmp_output.join("public")
    out = tmp_output.join("out")
    public_dir.join("assets").mkpath
    public_dir.join(".well-known").mkpath
    public_dir.join("assets/old.css").write("x")
    public_dir.join(".well-known/security.txt").write("hi")
    public_dir.join("icon.svg").write("<svg/>")
    public_dir.join("404.html").write("static")
    out.mkpath
    out.join("404.html").write("rendered")

    Kiln::Assets.copy_public(from: public_dir, to: out, report: @report)

    assert_equal "<svg/>", out.join("icon.svg").read
    assert_equal "hi", out.join(".well-known/security.txt").read
    assert_equal "rendered", out.join("404.html").read
    assert_not out.join("assets").exist?
    assert_equal %w[.well-known/security.txt icon.svg], @report.written.sort
    assert_equal [ [ :write, "/404.html" ] ], @report.warnings.map { [ it.kind, it.path ] }
  end

  test "precompile decision" do
    assets = ActiveSupport::OrderedOptions.new
    assets.manifest_path = tmp_output.join("assets/.manifest.json")
    app = Struct.new(:config).new(Struct.new(:assets).new(assets))

    assets.server = true
    assert_not Kiln::Assets.precompile?(app), "dynamic Propshaft needs no precompile"

    assets.server = false
    assert Kiln::Assets.precompile?(app)

    assets.manifest_path.dirname.mkpath
    assets.manifest_path.write("{}")
    assert Kiln::Assets.precompile?(app), "a compiled public/assets can be stale"

    assert_nil Kiln::Assets.precompile(dummy_app), "test env serves assets dynamically"
  end

  test "precompiles into a temp dir, never public/assets, and cleans up" do
    assets = dummy_app.config.assets
    original = assets.slice(:server, :output_path, :manifest_path)
    assets.server = false

    cleanup = Kiln::Assets.precompile(dummy_app)
    dir = assets.output_path
    assert_not_equal original[:output_path], dir
    assert_equal dir.join(".manifest.json"), assets.manifest_path
    assert Dir.glob(dir.join("application-*.css")).any?
    assert_not Rails.root.join("public/assets").exist?

    cleanup.call
    assert_not dir.exist?
    assert_equal original.except(:server), assets.slice(:output_path, :manifest_path)
  ensure
    assets.merge!(original)
  end

  test "exports precompiled assets from the compile directory" do
    assets = dummy_app.config.assets
    original = assets.slice(:server, :output_path, :manifest_path)
    assets.server = false
    cleanup = Kiln::Assets.precompile(dummy_app)
    renderer = StubRenderer.new({})
    page "logo.html", %(<img src="#{asset_url("logo.svg")}"><img src="/assets/../../Gemfile">)
    export(renderer:)

    path = asset_url("logo.svg")
    assert_equal dummy_app.root.join("app/assets/images/logo.svg").binread, tmp_output.join(path.delete_prefix("/")).binread
    assert_equal [ "/assets/../../Gemfile" ], renderer.requested, "paths outside the compile directory go to the app"
  ensure
    cleanup&.call
    assets.merge!(original)
  end

  test "reports an app/assets/builds folder created after boot" do
    builds = dummy_app.root.join("app/assets/builds")
    assert_nothing_raised { Kiln::Assets.check_builds!(dummy_app) }

    builds.mkpath
    error = assert_raises(Kiln::Error) { Kiln::Assets.check_builds!(dummy_app) }
    assert_includes error.message, "app/assets/builds/.keep"

    dummy_app.config.assets.paths << builds
    assert_nothing_raised { Kiln::Assets.check_builds!(dummy_app) }
  ensure
    dummy_app.config.assets.paths.delete(builds)
    FileUtils.rm_rf(builds)
  end

  private
    class StubRenderer
      attr_reader :requested

      def initialize(bodies)
        @bodies = bodies
        @requested = []
      end

      def get(path)
        @requested << path
        body = @bodies[path]
        Kiln::Response.new(path:, status: body ? 200 : 404, headers: { "content-type" => "text/plain" }, body: body.to_s)
      end
    end

    def export(renderer: @renderer)
      Kiln::Assets.new(renderer:, output: tmp_output, config: @config, report: @report).export
    end

    def render(path, file)
      page file, @renderer.get(path).body
    end

    def page(file, html)
      tmp_output.join(file).dirname.mkpath
      tmp_output.join(file).binwrite(html)
    end

    def asset_url(name) = ActionController::Base.helpers.asset_path(name)

    def written?(pattern) = @report.written.any? { it.match?(pattern) }

  test "runs bundle builds hooked into assets:precompile when assets are served dynamically" do
    require "rake"
    dummy_app.load_tasks unless Rake::Task.task_defined?("assets:precompile")
    runs = 0
    Rake::Task.define_task("kiln_test:bundle") { runs += 1 }
    Rake::Task["assets:precompile"].enhance([ "kiln_test:bundle" ])

    2.times { assert_nil Kiln::Assets.precompile(dummy_app) }
    assert_equal 2, runs, "runs on every build, not once per process"
  ensure
    Rake::Task["assets:precompile"].prerequisites.delete("kiln_test:bundle")
  end
end
