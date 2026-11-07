namespace :kiln do
  desc "List every GET route and whether Kiln builds, skips, or misses it"
  task routes: :environment do
    report = Kiln::Report.new
    router = Kiln::Router.new(Rails.application.routes, Kiln.pages, report:)
    puts router.table
    if report.failure?
      puts "", report
      exit 1
    end
  end
end
