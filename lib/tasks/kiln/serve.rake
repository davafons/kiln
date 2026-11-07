namespace :kiln do
  desc "Serve the built output like a static host (PORT, default 4000)"
  task serve: :environment do
    output = Kiln.config.output_path
    abort "Kiln: #{output} does not exist. Run kiln:build first." unless output.directory?

    port = Integer(ENV.fetch("PORT", 4000))
    puts "Kiln: serving #{output} at http://localhost:#{port}"
    Kiln::Server.start(output, port:)
  end
end
