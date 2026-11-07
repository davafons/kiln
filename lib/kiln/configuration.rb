module Kiln
  class Configuration
    # Output directory, relative to Rails.root unless absolute.
    attr_accessor :output
    # Public base URL ("https://davafons.com"). Used by the sitemap and absolute_urls processor.
    attr_accessor :url
    # :directory ("/now" -> now/index.html) or :file ("/now" -> now.html).
    attr_accessor :paths
    # :referenced (only assets the output uses) or :all (everything under /assets).
    attr_accessor :assets
    # Writes a CNAME file with this domain when set.
    attr_accessor :cname
    # Removes `sourceMappingURL` comments from JS and CSS.
    attr_accessor :strip_source_maps
    # Extra HTML processors: objects responding to call(html, context) -> html.
    attr_accessor :processors
    # Built-in optional processors, off by default.
    attr_accessor :absolute_urls, :external_links
    # Path rendered to 404.html (expected to respond with 404 or 200), nil to skip.
    attr_accessor :not_found
    # :file (_redirects), :meta_refresh (HTML pages), :both, or false.
    attr_accessor :redirects
    # Writes sitemap.xml when true and `url` is set.
    attr_accessor :sitemap
    # Runs the verifier (links, anchors, importmap) after every build.
    attr_accessor :verify
    # Copy public/ into the output (minus public/assets).
    attr_accessor :copy_public

    attr_reader :before_build_hooks, :after_build_hooks
    attr_writer :host

    def initialize
      @output = "dist"
      @url = nil
      @host = nil
      @paths = :directory
      @assets = :referenced
      @cname = nil
      @strip_source_maps = true
      @processors = []
      @absolute_urls = false
      @external_links = false
      @not_found = nil
      @redirects = :file
      @sitemap = true
      @verify = true
      @copy_public = true
      @before_build_hooks = []
      @after_build_hooks = []
    end

    # Host sent with every request. Derived from `url`, falls back to "localhost".
    def host
      @host || (url && URI(url).host) || "localhost"
    end

    def output_path(root = Rails.root)
      Pathname(output).absolute? ? Pathname(output) : Pathname(root).join(output)
    end

    def before_build(&block) = @before_build_hooks << block
    def after_build(&block) = @after_build_hooks << block
  end
end
