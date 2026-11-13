require "fileutils"

module Kiln
  class Assets
    # Gets the app's assets ready before pages render.
    module Compiler
      class << self
        # Compiles assets in-process when the app does not serve them dynamically. The compile goes to
        # a temporary directory, never public/assets, so a development server of the same app that
        # boots meanwhile never sees a production manifest. Returns a callable that restores the asset
        # config and removes the directory, or nil when nothing was compiled. When assets are served
        # dynamically, still runs the build steps hooked into assets:precompile (tailwindcss:build,
        # javascript:build, css:build), so a development build never ships stale bundles.
        def run(app)
          cleanup = precompile?(app) ? compile(app) : build_bundles(app)
          check_builds!(app)
          cleanup
        rescue Kiln::Error
          cleanup&.call
          raise
        end

        # A compiled public/assets is ignored: it can be older than the source, and a build must ship
        # the assets the source compiles to now.
        def precompile?(app)
          assets = app.config.respond_to?(:assets) && app.config.assets
          return false unless assets.respond_to?(:server) && assets.manifest_path

          !assets.server
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

        private
          def compile(app)
            assets = app.config.assets
            original = assets.slice(:output_path, :manifest_path)
            dir = Pathname(Dir.mktmpdir("kiln-assets"))
            cleanup = -> do
              assets.merge!(original)
              FileUtils.rm_rf(dir)
            end
            assets.merge!(output_path: dir, manifest_path: dir.join(".manifest.json"))
            begin
              invoke(precompile_task(app))
            rescue Kiln::Error
              cleanup.call
              raise
            end
            cleanup
          end

          def build_bundles(app)
            precompile_task(app)&.prerequisite_tasks&.each do |task|
              invoke(task) unless task.name.end_with?("environment")
            end
            nil
          end

          def precompile_task(app)
            require "rake"
            app.load_tasks unless Rake::Task.task_defined?("assets:precompile")
            Rake::Task["assets:precompile"] if Rake::Task.task_defined?("assets:precompile")
          end

          def invoke(task)
            task.reenable
            task.invoke
          rescue StandardError => error
            raise Kiln::Error, "#{task.name} failed: #{error.class}: #{error.message}"
          end
      end
    end
  end
end
