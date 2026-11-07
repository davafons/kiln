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

    def building!
      previous = @building
      @building = true
      build_cache.clear
      yield
    ensure
      @building = previous
      build_cache.clear
    end

    # Memoization store that lives for one build. Cleared before and after every build.
    def build_cache
      @build_cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def reset!
      @config = nil
      @pages = nil
      @building = nil
      @build_cache = nil
    end
  end
end

require "kiln/railtie" if defined?(Rails::Railtie)
