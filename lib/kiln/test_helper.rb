require "kiln"
require "tmpdir"
require "nokogiri"

module Kiln
  # Minitest assertions for apps built with Kiln.
  #
  #   require "kiln/test_helper"
  #
  #   class StaticSiteTest < ActiveSupport::TestCase
  #     include Kiln::TestHelper
  #
  #     test("builds repeatably") { kiln_build(repeatable: true) { assert it.join("index.html").file? } }
  #     test("home page") { assert_page "/", selector: "h1", text: "Home" }
  #     test("sitemap") { assert kiln_site.join("sitemap.xml").file? }
  #   end
  module TestHelper
    # Builds shared by kiln_site, one per test class, app and config.
    SITES = {}

    # Builds into a temp dir, fails with the report on any error, and yields the output path.
    # Returns the Build when no block is given (the temp dir is then left for the caller).
    # With repeatable: true it builds a second time and fails with the diff when the two outputs
    # differ, then yields the first output.
    def kiln_build(app: Rails.application, config: Kiln.config, repeatable: false)
      dir = Pathname(Dir.mktmpdir("kiln-build"))
      build = Build.new(app:, config:, output: dir)
      assert build.run.success?, build.report.to_s
      if repeatable
        kiln_build(app:, config:) do |second|
          diff = TreeDiff.call(dir, second)
          assert diff.empty?, "Kiln output differs between two builds:\n#{diff}"
        end
      end
      return build unless block_given?

      yield dir
    ensure
      FileUtils.rm_rf(dir) if dir && block_given?
    end

    # The output of one build shared by every test in the class, as a Pathname. The first call builds
    # into a temp dir, removed when the test run ends. When that build fails, every test that calls
    # kiln_site fails with its report, and the site is not built again.
    def kiln_site(app: Rails.application, config: Kiln.config)
      build = SITES[[ self.class, app, config ]] ||= begin
        dir = Pathname(Dir.mktmpdir("kiln-site"))
        Minitest.after_run { FileUtils.rm_rf(dir) }
        Build.new(app:, config:, output: dir).tap(&:run)
      end
      assert build.report.success?, build.report.to_s
      build.output
    end

    # Renders one path the way a build does (CSRF tokens stripped) and asserts it succeeds.
    # Optional `selector` must match, and contain `text` when given. Returns the processed body.
    def assert_page(path, status: 200, selector: nil, text: nil, app: Rails.application, config: Kiln.config)
      response = Kiln.building! { Renderer.new(app, host: config.host).get(path) }
      assert_equal status, response.status, "Expected #{path} to respond with #{status}"

      body = response.output_body

      if selector
        nodes = Nokogiri::HTML5(body).css(selector)
        assert nodes.any?, "Expected #{path} to contain #{selector}"
        assert nodes.any? { it.text.include?(text) }, "Expected #{selector} on #{path} to contain #{text.inspect}" if text
      end
      body
    end
  end
end
