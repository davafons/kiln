require "nokogiri"
require "set"

module Kiln
  # Finds the /assets/* files the output uses and exports them. Compiled assets are read from the
  # compile directory; dynamic Propshaft (development, test) serves them through the app.
  class Assets
    CSS_REFERENCE = /url\(\s*["']?([^"')]+?)["']?\s*\)|@import\s+["']([^"']+)["']/
    EXTERNAL = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i

    def initialize(renderer:, writer:, host:, report:, app: Rails.application)
      @renderer = renderer
      @writer = writer
      @host = host
      @report = report
      @app = app
    end

    def export
      queue = referenced_paths
      seen = Set.new

      while (path = queue.shift)
        next unless seen.add?(path)
        queue.concat(fetch(path))
      end
    end

    private
      # Writes one asset and returns the asset paths it references (CSS url() and @import).
      def fetch(path)
        body = compiled(path)
        unless body
          response = @renderer.get(path)
          unless response.success?
            @report.error(:asset, "responded with #{response.status}", path:)
            return []
          end
          body = response.body
        end

        extension = File.extname(path)
        body = Processors::StripSourceMaps.call(body) if %w[.js .css].include?(extension)
        @writer.write_file(path.delete_prefix("/"), body)
        extension == ".css" ? css_references(path, body) : []
      rescue StandardError => error
        @report.error(:asset, "#{error.class}: #{error.message}", path:)
        []
      end

      # The file from the compile directory when assets are precompiled, or nil.
      def compiled(path)
        assets = @app.config.assets
        return if assets.server

        dir = Pathname(assets.manifest_path).dirname.expand_path
        file = dir.join(path.delete_prefix("#{prefix}/")).expand_path
        file.binread if file.to_s.start_with?("#{dir}/") && file.file?
      end

      # Invalid importmaps are left to the verifier, which reports them with their page.
      def referenced_paths
        Dir.glob("**/*.html", base: @writer.output).sort.flat_map do |relative|
          doc = Nokogiri::HTML5(@writer.output.join(relative).read)
          doc.xpath(Links::ELEMENTS).flat_map { Links.in(it) } +
            doc.css('script[type="importmap"]').flat_map { Links.importmap(it.text).to_a }
        end.filter_map { asset_path(it) }.uniq
      end

      def css_references(css_path, body)
        body.to_s.scan(CSS_REFERENCE).filter_map do |url, import|
          ref = (url || import).strip
          next if ref.empty? || ref.match?(EXTERNAL)

          asset_path(URI.join("http://kiln#{css_path}", ref).path)
        rescue URI::Error
          nil
        end
      end

      # Normalizes a URL to an asset path ("/assets/app-abc.css"), or nil when it isn't one of ours.
      def asset_path(url)
        uri = URI.parse(url.to_s.strip)
        return if uri.host && uri.host != @host

        uri.path if uri.path&.start_with?("#{prefix}/")
      rescue URI::Error
        nil
      end

      def prefix
        @prefix ||= @app.config.assets.prefix.to_s.chomp("/")
      end
  end
end
