require "fileutils"

module Kiln
  # Runs the whole pipeline and returns a Report. Never raises for page-level problems: those go in
  # the report so the build can show every failure at once.
  class Build
    # Development middleware that injects markup into every HTML response.
    DEV_MIDDLEWARE = %w[Hotwire::Spark::Middleware WebConsole::Middleware Rack::MiniProfiler Rack::LiveReload].freeze
    # Source-position attributes for in-page editors: Herb source attribution, Tensaku, and the content
    # layer's own data-md-source.
    EDITOR_MARKUP = /\sdata-(?:herb-[\w-]+|tensaku-[\w-]+|md-source)=/

    attr_reader :app, :config, :output, :report, :manifest

    def initialize(app: Rails.application, config: Kiln.config, pages: Kiln.pages, output: nil)
      @app = app
      @config = config
      @pages = pages
      @output = Pathname(output || config.output_path(app.root))
      # Pages are written here and replace the output only when the whole build succeeds, so a failed
      # build leaves the previous output as it was.
      @stage = @output.dirname.join(".#{@output.basename}.kiln-build")
      @report = Report.new
      @manifest = Manifest.new
      @redirects = []
      @editor_markup = []
    end

    # Pages added, removed and changed since the previous build of the configured output, or nil.
    def changes
      @previous_manifest&.diff(manifest)
    end

    def run
      Kiln.building!(renderer:) do
        guard_output!
        guard_dev_middleware!
        ensure_secret_key_base
        cleanup = Assets::Compiler.run(app)
        begin
          prepare_stage
          render_pages
          Assets.new(renderer:, writer:, host: config.host, report:, app:).export
          write_extras
          Verifier.new(@stage, config:).verify(report)
          publish if report.success?
        ensure
          cleanup&.call
          FileUtils.rm_rf(@stage)
        end
      end
      report
    end

    private
      def renderer
        @renderer ||= Renderer.new(app, host: config.host)
      end

      def writer
        @writer ||= Writer.new(@stage, mode: config.paths, report:)
      end

      def render_pages
        pages = Router.new(app.routes, @pages, report:).pages
        pages.reject { it.path == config.not_found }.each { render_page(it) }
        render_not_found if config.not_found
        report_editor_markup
      end

      def render_page(page)
        response = Kiln.response_for(page.path)

        if response.redirect?
          @redirects << Redirects::Entry.new(from: page.path, to: response.location, status: response.status)
        elsif response.success?
          body = response.output_body
          @editor_markup << page.path if response.html? && body.match?(EDITOR_MARKUP)
          file = writer.write(page.path, response.content_type, body)
          manifest.add(page.path, file:, body:, content_type: response.content_type, noindex: Sitemap.noindex?(response, body))
        else
          report.error(:render, "responded with #{response.status}", path: page.path)
        end
      rescue StandardError => error
        report.error(:render, describe(error), path: page.path)
      end

      # The not_found path is written only as 404.html, whether or not it is a route.
      def render_not_found
        response = Kiln.response_for(config.not_found)
        unless [ 200, 404 ].include?(response.status)
          return report.error(:render, "404 page responded with #{response.status}", path: config.not_found)
        end

        writer.write_file("404.html", response.output_body)
      rescue StandardError => error
        report.error(:render, describe(error), path: config.not_found)
      end

      def report_editor_markup
        return if @editor_markup.empty?

        pages = @editor_markup.first(3).join(", ") + (@editor_markup.size > 3 ? " and #{@editor_markup.size - 3} more" : "")
        report.error(:editor_markup, "data-herb-*, data-tensaku-* or data-md-source attributes reached #{pages}. " \
          "Turn off Herb source attribution, Tensaku and Kiln::Content.source_positions outside development, " \
          "or build in production.")
      end

      # Everything in the output that is not a rendered page or an asset.
      def write_extras
        write_files
        writer.copy_public(app.root.join("public"), generated: generated_files)
        Redirects.new(@redirects, host: config.host).write(writer) if @redirects.any?
        Sitemap.new(manifest, url: config.url).write(writer) if config.url
        write_cname if config.cname
      end

      def write_files
        config.files.each do |target, source|
          source = app.root.join(source)
          next report.error(:write, "#{source} does not exist", path: "/#{target}") unless source.file?

          writer.write_file(target.to_s, source.binread)
        rescue Kiln::Error => error
          report.error(:write, error.message, path: "/#{target}")
        end
      end

      # Files Kiln writes on purpose that may also exist in public/ (Rails ships a public/404.html).
      def generated_files
        [ ("404.html" if config.not_found), ("CNAME" if config.cname), *config.files.keys.map(&:to_s) ].compact
      end

      # config.cname = true takes the host from config.url.
      def write_cname
        host = config.cname == true ? config.url && URI(config.url).host : config.cname
        return report.error(:write, "config.cname = true needs config.url", path: "/CNAME") unless host

        writer.write_file("CNAME", "#{host}\n")
      end

      # The manifest is build state, not part of the site: it lives in tmp/, and only for the configured
      # output, so throwaway builds (tests, temp dirs) never overwrite it.
      def manifest_dir
        app.root.join("tmp") if output.expand_path == config.output_path(app.root).expand_path
      end

      def prepare_stage
        previous = manifest_dir&.join(Manifest::FILENAME)
        @previous_manifest = Manifest.load(previous) if previous&.file?
        FileUtils.rm_rf(@stage)
        FileUtils.mkdir_p(@stage)
      end

      def publish
        FileUtils.rm_rf(output)
        File.rename(@stage, output)
        return unless manifest_dir

        FileUtils.mkdir_p(manifest_dir)
        manifest.write(manifest_dir)
      end

      # Refuse to wipe anything that contains the app.
      def guard_output!
        root = app.root.expand_path
        out = output.expand_path
        if out == root || root.to_s.start_with?("#{out}/") || out.root?
          raise Kiln::Error, "Refusing to use #{out} as the output directory"
        end
      end

      def guard_dev_middleware!
        active = app.middleware.map(&:name) & DEV_MIDDLEWARE
        return if active.empty?

        raise Kiln::Error, "#{active.to_sentence} would add development markup to every page. " \
          "Load it only under bin/rails server (if defined?(Rails::Server)), or build in production."
      end

      # Rails refuses to render in production without a secret. A build ships nothing signed (CSRF tokens
      # are stripped), so an app without one gets a throwaway secret instead of a failed build.
      def ensure_secret_key_base
        app.config.secret_key_base
      rescue ArgumentError
        app.config.secret_key_base = SecureRandom.hex(64)
      end

      def describe(error)
        where = error.backtrace&.find { it.start_with?(app.root.to_s) }&.delete_prefix("#{app.root}/")
        [ "#{error.class}: #{error.message}", where && "(#{where})" ].compact.join(" ")
      end
  end
end
