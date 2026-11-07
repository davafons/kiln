namespace :kiln do
  # Rails and gems such as turbo-rails read secret_key_base while the app boots. A build ships nothing
  # signed, so an app without a secret of its own boots with Rails' dummy secret.
  task :secret_key_base do
    next unless ENV["SECRET_KEY_BASE"].to_s.empty? && ENV["RAILS_MASTER_KEY"].to_s.empty?
    next if Dir[File.join(Dir.pwd, "config/{master.key,credentials/*.key}")].any?

    ENV["SECRET_KEY_BASE_DUMMY"] ||= "1"
  end

  desc "Render every page into the output directory"
  task build: [ :secret_key_base, :environment ] do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    build = Kiln::Build.new
    # One log line per request buries the report. Warnings and errors still show; VERBOSE=1 shows all.
    report = ENV["VERBOSE"] ? build.run : Rails.logger.silence(Logger::WARN) { build.run }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    puts report
    if (changes = build.changes) && report.success?
      summary = changes.map { |kind, paths| "#{paths.size} #{kind}" }.join(", ")
      puts "Pages since last build: #{summary}"
      changes.each { |kind, paths| paths.each { puts "  #{kind}: #{it}" } }
    end
    puts format("Output: %s (%.1fs)", build.output, elapsed)
    exit 1 if report.failure?
  end
end
