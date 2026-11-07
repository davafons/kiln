require "fileutils"

module Kiln
  # Runs the whole pipeline and returns a Report. Never raises for page-level problems: those go in
  # the report so the build can show every failure at once.
  class Build
    # Passed to before_build / after_build hooks.
    Context = Data.define(:output, :env, :manifest, :report)

    attr_reader :app, :config, :pages_dsl, :output, :report, :manifest, :previous_manifest

    def initialize(app: Rails.application, config: Kiln.config, pages: Kiln.pages, output: nil)
      @app = app
      @config = config
      @pages_dsl = pages
      @output = Pathname(output || config.output_path(app.root))
      @report = Report.new
      @manifest = Manifest.new
      @redirects = []
    end

    # Pages added, removed and changed since the previous build in the same output, or nil.
    def changes
      previous_manifest&.diff(manifest)
    end

    def run
      Kiln.building! do
        guard_output!
        guard_static_files!
        cleanup = Assets.precompile(app)
        begin
          run_hooks(config.before_build_hooks)
          prepare_output

          pages = Router.new(app.routes, pages_dsl, report:).pages
          pages.reject { it.path == config.not_found }.each { render_page(it) }
          render_not_found if config.not_found

          Assets.new(renderer:, output:, config:, report:).export
          Assets.copy_public(from: app.root.join("public"), to: output, report:, generated: generated_files) if config.copy_public
          write_redirects if config.redirects && @redirects.any?
          Sitemap.new(manifest, url: config.url).write(output) if config.sitemap && config.url
          write_cname if config.cname
          manifest.write(output)

          Verifier.new(output, config:).verify(report) if config.verify
          run_hooks(config.after_build_hooks)
        ensure
          cleanup&.call
        end
      end
      report
    end

    private
      def renderer
        @renderer ||= Renderer.new(app, host: config.host)
      end

      def writer
        @writer ||= Writer.new(output, mode: config.paths)
      end

      def render_page(page)
        response = renderer.get(page.path)

        if response.redirect?
          @redirects << Redirects::Entry.new(from: page.path, to: response.location, status: response.status)
        elsif response.success?
          body = response.html? ? Processors.apply(response.body, Processors::Context.new(path: page.path, config:, response:)) : response.body
          file = writer.write(page.path, response.content_type, body)
          manifest.add(page.path, file:, body:, content_type: response.content_type, noindex: Sitemap.noindex?(response, body))
          report.wrote(file)
        else
          report.error(:render, "responded with #{response.status}", path: page.path)
        end
      rescue StandardError => error
        report.error(:render, describe(error), path: page.path)
      end

      def render_not_found
        response = renderer.get(config.not_found)
        unless [ 200, 404 ].include?(response.status)
          return report.error(:render, "404 page responded with #{response.status}", path: config.not_found)
        end

        body = Processors.apply(response.body, Processors::Context.new(path: config.not_found, config:, response:))
        report.wrote(writer.write_file("404.html", body))
      rescue StandardError => error
        report.error(:render, describe(error), path: config.not_found)
      end

      def write_redirects
        Redirects.new(@redirects, mode: config.redirects, writer:, host: config.host, url: config.url).write(output).each { report.wrote(it) }
      end

      # Files Kiln writes on purpose that may also exist in public/ (Rails ships a public/404.html).
      def generated_files
        [ ("404.html" if config.not_found), ("CNAME" if config.cname) ].compact
      end

      def write_cname
        report.wrote(writer.write_file("CNAME", "#{config.cname}\n"))
      end

      def run_hooks(hooks)
        context = Context.new(output:, env: Rails.env, manifest:, report:)
        hooks.each do |hook|
          hook.call(context)
        rescue StandardError => error
          report.error(:hook, describe(error))
        end
      end

      def prepare_output
        previous = output.join(Manifest::FILENAME)
        @previous_manifest = Manifest.load(previous) if previous.file?
        FileUtils.rm_rf(output)
        FileUtils.mkdir_p(output)
      end

      # Refuse to wipe anything that contains the app.
      def guard_output!
        root = app.root.expand_path
        out = output.expand_path
        if out == root || root.to_s.start_with?("#{out}/") || out.root?
          raise Kiln::Error, "Refusing to use #{out} as the output directory"
        end
      end

      # After a precompile, assets are fetched from public/assets through ActionDispatch::Static.
      def guard_static_files!
        return unless app.config.respond_to?(:assets) && !app.config.assets.server
        return if app.config.public_file_server.enabled

        raise Kiln::Error, "Kiln fetches compiled assets through the public file server. " \
          "Set config.public_file_server.enabled = true for the build environment."
      end

      def describe(error)
        where = error.backtrace&.find { it.start_with?(app.root.to_s) }&.delete_prefix("#{app.root}/")
        [ "#{error.class}: #{error.message}", where && "(#{where})" ].compact.join(" ")
      end
  end
end
