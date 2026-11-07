require "test_helper"

class Kiln::CheckTest < Kiln::TestCase
  setup do
    @config = Kiln.config.dup
    @config.output = tmp_output.to_s
  end

  test "passes when the committed output matches a fresh build" do
    Kiln::Build.new(config: @config).run
    assert Kiln::Check.new(config: @config).run.success?
  end

  test "lists the files that differ" do
    Kiln::Build.new(config: @config).run
    tmp_output.join("about/index.html").write("stale")
    tmp_output.join("old.html").write("gone")
    tmp_output.join("ping.txt").delete

    result = Kiln::Check.new(config: @config).run
    refute result.success?
    assert_equal [ "ping.txt" ], result.diff.added
    assert_equal [ "old.html" ], result.diff.removed
    assert_equal [ "about/index.html" ], result.diff.changed
  end
end
