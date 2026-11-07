require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require "kiln/content"

# Hotwire Spark injects markup into every page, so only the development server loads it. A build in
# development would fail with it active.
if Rails.env.development? && defined?(Rails::Server)
  require "action_cable/engine"
  require "hotwire-spark"
end

module Docs
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
