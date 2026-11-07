namespace :kiln do
  desc "Check internal links, anchors and importmap modules in the built output"
  task verify: :environment do
    output = Kiln.config.output_path
    abort "Kiln: #{output} does not exist. Run kiln:build first." unless output.directory?

    report = Kiln::Verifier.new(output, config: Kiln.config).verify(Kiln::Report.new)
    if report.success?
      puts "Kiln verify: no problems found in #{output}."
    else
      puts report.to_s(title: "Kiln verify")
      exit 1
    end
  end
end
