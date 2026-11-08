require "rails/railtie"

module Kiln
  class Railtie < ::Rails::Railtie
    # config/kiln.rb holds Kiln.configure and Kiln.pages. Param sources are lambdas, so loading it
    # early (before the app's models exist) is fine.
    initializer "kiln.load_config", before: :load_config_initializers do |app|
      file = app.root.join("config/kiln.rb")
      load file if file.exist?
    end

    # Requests carry the configured host. Allow it when the app restricts hosts.
    initializer "kiln.hosts", after: "kiln.load_config" do |app|
      hosts = app.config.hosts
      hosts << Kiln.config.host if hosts.any? && !hosts.include?(Kiln.config.host)
    end

    # In :directory mode "/now" is written as now/index.html, which static hosts serve at "/now/" and
    # reach from "/now" with a redirect. Route helpers add the trailing slash so links point at the
    # served URL. Paths with a dot (feed.xml) are left alone, and an app that sets trailing_slash in
    # default_url_options keeps its own value.
    config.after_initialize do |app|
      options = app.routes.default_url_options
      options[:trailing_slash] = true if Kiln.config.paths == :directory && !options.key?(:trailing_slash)
    end

    rake_tasks do
      Dir[File.expand_path("../tasks/kiln/*.rake", __dir__)].sort.each { load it }
    end
  end
end
