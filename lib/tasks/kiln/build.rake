namespace :kiln do
  desc "Render every page into the output directory"
  task build: :environment do
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
