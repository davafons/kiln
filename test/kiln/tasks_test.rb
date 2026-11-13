require "test_helper"
require "open3"

# Runs the rake tasks in the dummy app as a separate process, the way a site runs them.
class Kiln::TasksTest < Kiln::TestCase
  DUMMY = Rails.root

  def rails(*args, **env)
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => nil, "RAILS_MASTER_KEY" => nil, "KILN_OUTPUT" => tmp_output.join("site").to_s, **env }
    output, status = Open3.capture2e(env, "bin/rails", *args, chdir: DUMMY.to_s)
    [ output, status.exitstatus ]
  end

  test "kiln:build compiles assets and builds in production without a secret" do
    output, status = rails("kiln:build")

    assert_equal 0, status, output
    assert_match "Kiln build succeeded", output
    assert_match "(production,", output
    assert Dir[tmp_output.join("site/assets/application-*.css")].any?
    assert_not DUMMY.join("public/assets").exist?
  end

  test "kiln:build exits 1 with the report and leaves the output as it was" do
    tmp_output.join("site").mkpath
    tmp_output.join("site/index.html").write("previous")
    output, status = rails("kiln:build", "KILN_FAIL" => "1")

    assert_equal 1, status, output
    assert_match "Kiln build failed with 1 error:", output
    assert_match "/missing.txt:", output
    assert_match "Output left unchanged", output
    assert_equal "previous", tmp_output.join("site/index.html").read
  end

  test "kiln:serve boots without a secret and refuses an output that does not exist" do
    output, status = rails("kiln:serve")

    assert_equal 1, status
    assert_match "Run kiln:build first", output
  end
end
