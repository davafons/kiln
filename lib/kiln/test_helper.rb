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
  #     test("builds the same output twice") { assert_repeatable_build }
  #     test("home page") { assert_page "/", selector: "h1", text: "Home" }
  #   end
  module TestHelper
    # Builds into a temp dir, fails with the report on any error, and yields the output path.
    # Returns the Build when no block is given (the temp dir is then left for the caller).
    def kiln_build(app: Rails.application, config: Kiln.config)
      dir = Dir.mktmpdir("kiln-build")
      build = Build.new(app:, config:, output: dir)
      assert build.run.success?, build.report.to_s
      return build unless block_given?

      begin
        yield Pathname(dir)
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    # Builds twice and asserts both outputs are byte-identical.
    def assert_repeatable_build(app: Rails.application, config: Kiln.config)
      kiln_build(app:, config:) do |first|
        kiln_build(app:, config:) do |second|
          diff = TreeDiff.call(first, second)
          assert diff.empty?, "Kiln output differs between two builds:\n#{diff}"
        end
      end
    end

    # Renders one path the way a build does (processors included) and asserts it succeeds.
    # Optional `selector` must match, and contain `text` when given. Returns the processed body.
    def assert_page(path, status: 200, selector: nil, text: nil, app: Rails.application, config: Kiln.config)
      response = Kiln.building! { Renderer.new(app, host: config.host).get(path) }
      assert_equal status, response.status, "Expected #{path} to respond with #{status}"

      body = response.body
      body = Processors.apply(body, Processors::Context.new(path:, config:, response:)) if response.html?

      if selector
        nodes = Nokogiri::HTML5(body).css(selector)
        assert nodes.any?, "Expected #{path} to contain #{selector}"
        assert nodes.any? { it.text.include?(text) }, "Expected #{selector} on #{path} to contain #{text.inspect}" if text
      end
      body
    end
  end
end
