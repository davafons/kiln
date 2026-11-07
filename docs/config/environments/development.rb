Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
  config.active_support.deprecation = :log
  config.secret_key_base = "docs-development"

  # Hotwire Spark is only loaded by bin/rails server (see config/application.rb).
  if defined?(Hotwire::Spark)
    config.action_cable.cable = { "adapter" => "async" }
    config.hotwire.spark.html_extensions += %w[md]
  end
end
