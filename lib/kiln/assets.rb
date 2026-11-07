require "fileutils"
require "json"
require "nokogiri"
require "set"

module Kiln
  # Finds the /assets/* files the output uses and exports them. Compiled assets are read from the
  # compile directory; dynamic Propshaft (development, test) serves them through the app.
  class Assets
    CSS_REFERENCE = /url\(\s*["']?([^"')]+?)["']?\s*\)|@import\s+["']([^"']+)["']/
    EXTERNAL = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i

    class << self
      # Compiles assets in-process when the app does not serve them dynamically. The compile goes to a
      # temporary directory, never public/assets, so a development server of the same app that boots
      # meanwhile never sees a production manifest. Returns a callable that restores the asset config
      # and removes the directory, or nil when nothing was compiled. When assets are served
      # dynamically, still runs the build steps hooked into assets:precompile (tailwindcss:build,
      # javascript:build, css:build), so a development build never ships stale bundles.
      def precompile(app)
        return build_bundles(app) unless precompile?(app)

        assets = app.config.assets
        original = assets.slice(:output_path, :manifest_path)
        dir = Pathname(Dir.mktmpdir("kiln-assets"))
        cleanup = -> do
          assets.merge!(original)
          FileUtils.rm_rf(dir)
        end
        assets.merge!(output_path: dir, manifest_path: dir.join(".manifest.json"))
        begin
          run_precompile(app)
        rescue Kiln::Error
          cleanup.call
          raise
        end
        cleanup
      end

      def precompile?(app)
        assets = app.config.respond_to?(:assets) && app.config.assets
        return false unless assets.respond_to?(:server) && assets.manifest_path

        !assets.server && !Pathname(assets.manifest_path).exist?
      end

      # Propshaft only adds load paths that exist at boot. On a fresh checkout, a bundler such as
      # tailwindcss:build creates app/assets/builds during the build, too late to be served.
      def check_builds!(app)
        builds = app.root.join("app/assets/builds")
        paths = app.config.respond_to?(:assets) && app.config.assets.respond_to?(:paths) && app.config.assets.paths
        return unless paths && builds.directory? && paths.none? { Pathname(it) == builds }

        raise Kiln::Error, "app/assets/builds did not exist when the app booted, so its assets are not served. " \
          "Track app/assets/builds/.keep in version control, as a new Rails app does, and build again."
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
        def build_bundles(app)
          precompile_task(app)&.prerequisite_tasks&.each do |task|
            next if task.name.end_with?("environment")

            task.reenable
            task.invoke
          rescue StandardError => error
            raise Kiln::Error, "#{task.name} failed: #{error.class}: #{error.message}"
          end
          nil
        end

        def precompile_task(app)
          require "rake"
          app.load_tasks unless Rake::Task.task_defined?("assets:precompile")
          Rake::Task["assets:precompile"] if Rake::Task.task_defined?("assets:precompile")
        end

        def run_precompile(app)
          task = precompile_task(app)
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
        write(path, body)
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
