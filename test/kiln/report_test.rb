require "test_helper"

class Kiln::ReportTest < Kiln::TestCase
  test "a failure lists warnings, then errors grouped by kind" do
    report = Kiln::Report.new
    report.warn(:write, "public/404.html not copied", path: "/404.html")
    report.error(:render, "responded with 500", path: "/a")
    report.error(:uncovered_route, "GET /posts/:slug needs params")
    report.error(:render, "responded with 404", path: "/b")

    assert report.failure?
    assert_equal <<~TEXT.chomp, report.to_s
      warning /404.html: public/404.html not copied

      Kiln build failed with 3 errors:

        Render (2)
          /a: responded with 500
          /b: responded with 404

        Uncovered route (1)
          GET /posts/:slug needs params
    TEXT
  end

  test "a success counts the files written" do
    report = Kiln::Report.new
    %w[index.html index.html about/index.html].each { report.wrote(it) }

    assert report.success?
    assert_equal "Kiln build succeeded: 2 files written.", report.to_s
  end
end
