require "zeitwerk"
require "active_support"
require "active_support/core_ext"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/tasks")
loader.ignore("#{__dir__}/kiln/railtie.rb")
# Optional parts, loaded with an explicit require so eager loading never pulls in their gems.
loader.ignore("#{__dir__}/kiln/content.rb", "#{__dir__}/kiln/content")
loader.ignore("#{__dir__}/kiln/test_helper.rb")
loader.inflector.inflect("strip_csrf" => "StripCSRF")
loader.setup

module Kiln
  class Error < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Kiln.pages { params :post, -> { ... }; skip :up }
    def pages(&block)
      @pages ||= Pages.new
      @pages.instance_eval(&block) if block
      @pages
    end

    # True while a build is rendering pages. Views use it to hide dev-only things.
    def building?
      @building == true
    end

    def building!(renderer: nil)
      previous = [ @building, @renderer ]
      @building = true
      @renderer = renderer
      build_cache.clear
      yield
    ensure
      @building, @renderer = previous
      build_cache.clear
    end

    # Another page's body as a build writes it (CSRF tokens stripped), for pages built from other
    # pages, such as a search index. Raises Kiln::Error unless the page responds with 2xx.
    #
    #   pages = Docs::PAGES.map { { url: page_path(it), html: Kiln.render(page_path(it)) } }
    #
    # During a build the response is shared: the build writes the same response, so every page is
    # rendered once whichever asks for it first. Outside a build it renders on every call.
    def render(path)
      response = response_for(path)
      raise Error, "Kiln.render(#{path.inspect}) got a #{response.status} response" unless response.success?

      response.output_body
    end

    # The app's response for a path, cached for the build so the build and Kiln.render share it.
    # "/now" and "/now/" are the same page. A page that renders itself, directly or through other
    # pages, raises Kiln::Error.
    def response_for(path)
      path = path.to_s
      path = path.chomp("/") unless path == "/"
      build_cache.fetch([ :kiln_response, path ]) do
        rendering = Thread.current[:kiln_rendering] ||= []
        raise Error, "Kiln.render loops: #{[ *rendering, path ].join(" -> ")}" if rendering.include?(path)

        rendering.push(path)
        begin
          (@renderer || Renderer.new(Rails.application, host: config.host)).get(path)
        ensure
          rendering.pop
        end
      end
    end

    # Memoization store that lives for one build. Cleared before and after every build.
    def build_cache
      @build_cache ||= BuildCache.new
    end

    def reset!
      @config = nil
      @pages = nil
      @building = nil
      @build_cache = nil
      @renderer = nil
    end
  end
end

require "kiln/railtie" if defined?(Rails::Railtie)
