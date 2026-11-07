namespace :kiln do
  desc "Serve the built output like a static host (PORT, default 4000; BIND, default localhost)"
  task serve: :environment do
    output = Kiln.config.output_path
    abort "Kiln: #{output} does not exist. Run kiln:build first." unless output.directory?

    port = Integer(ENV.fetch("PORT", 4000))
    host = ENV.fetch("BIND", "localhost")
    puts "Kiln: serving #{output} at http://#{host}:#{port}"
    Kiln::Server.start(output, port:, host:)
  end
end
