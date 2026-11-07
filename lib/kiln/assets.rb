require "fileutils"
require "json"
require "nokogiri"
require "set"

module Kiln
  # Finds the /assets/* files the output uses and fetches them through the app, so the same code works
  # with dynamic Propshaft (development, test) and with precompiled assets served from public/assets.
  class Assets
    CSS_REFERENCE = /url\(\s*["']?([^"')]+?)["']?\s*\)|@import\s+["']([^"']+)["']/
    EXTERNAL = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i

    class << self
      # Compiles assets in-process when the app does not serve them dynamically. Returns a callable that
      # removes what the precompile created, or nil when nothing was compiled.
      def precompile(app)
        return unless precompile?(app)

        output_path = Pathname(app.config.assets.output_path)
        created = !output_path.exist?
        run_precompile(app)

        -> { created ? FileUtils.rm_rf(output_path) : FileUtils.rm_f(app.config.assets.manifest_path) }
      end

      def precompile?(app)
        assets = app.config.respond_to?(:assets) && app.config.assets
        return false unless assets.respond_to?(:server) && assets.manifest_path

        !assets.server && !Pathname(assets.manifest_path).exist?
      end

      # Copies public/ into the output, minus public/assets. Files already in the output win, with a
      # warning unless they are listed in `generated` (files Kiln writes on purpose, like 404.html).
      def copy_public(from:, to:, report:, generated: [])
        from = Pathname(from)
        return unless from.directory?

        Dir.glob("**/*", File::FNM_DOTMATCH, base: from).sort.each do |relative|
          source = from.join(relative)
          next if source.directory? || relative.start_with?("assets/")

          target = Pathname(to).join(relative)
          if target.exist?
            next if generated.include?(relative)

            report.warn(:write, "public/#{relative} not copied, a rendered file already exists", path: "/#{relative}")
          else
            FileUtils.mkdir_p(target.dirname)
            FileUtils.cp(source, target)
            report.wrote(relative)
          end
        end
      end

      private
        def run_precompile(app)
          require "rake"
          app.load_tasks unless Rake::Task.task_defined?("assets:precompile")
          task = Rake::Task["assets:precompile"]
          task.reenable
          task.invoke
        rescue StandardError => error
          raise Kiln::Error, "assets:precompile failed: #{error.class}: #{error.message}"
        end
    end

    def initialize(renderer:, output:, config:, report:, app: Rails.application)
      @renderer = renderer
      @output = Pathname(output)
      @config = config
      @report = report
      @app = app
    end

    def export
      queue = referenced_paths
      queue.concat(all_paths) if @config.assets == :all
      seen = Set.new

      while (path = queue.shift)
        next unless seen.add?(path)
        queue.concat(fetch(path))
      end
    end

    private
      # Writes one asset and returns the asset paths it references (CSS url() and @import).
      def fetch(path)
        response = @renderer.get(path)
        unless response.success?
          @report.error(:asset, "responded with #{response.status}", path:)
          return []
        end

        extension = File.extname(path)
        body = response.body
        body = Processors::StripSourceMaps.call(body) if @config.strip_source_maps && %w[.js .css].include?(extension)
        write(path, body)
        extension == ".css" ? css_references(path, body) : []
      rescue StandardError => error
        @report.error(:asset, "#{error.class}: #{error.message}", path:)
        []
      end

      def write(path, body)
        relative = path.delete_prefix("/")
        file = @output.join(relative)
        FileUtils.mkdir_p(file.dirname)
        File.binwrite(file, body)
        @report.wrote(relative)
      end

      def referenced_paths
        Dir.glob("**/*.html", base: @output).sort.flat_map do |relative|
          html_references(Nokogiri::HTML(File.read(@output.join(relative))))
        end.filter_map { asset_path(it) }.uniq
      end

      def html_references(doc)
        urls = doc.xpath("//@href | //@src").map(&:value)
        urls += doc.xpath("//@srcset").flat_map { |attr| attr.value.split(",").map { it.strip.split(/\s+/).first } }
        doc.css('script[type="importmap"]').each do |script|
          map = JSON.parse(script.text)
          urls += map.fetch("imports", {}).values
          urls += map.fetch("scopes", {}).values.flat_map(&:values)
        rescue JSON::ParserError
          @report.error(:asset, "invalid importmap JSON")
        end
        urls.compact
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

      def all_paths
        @app.assets.load_path.assets.map { "#{prefix}/#{it.digested_path}" }
      end

      # Normalizes a URL to an asset path ("/assets/app-abc.css"), or nil when it isn't one of ours.
      def asset_path(url)
        uri = URI.parse(url.to_s.strip)
        return if uri.host && uri.host != @config.host

        uri.path if uri.path&.start_with?("#{prefix}/")
      rescue URI::Error
        nil
      end

      def prefix
        @prefix ||= @app.config.assets.prefix.to_s.chomp("/")
      end
  end
end
