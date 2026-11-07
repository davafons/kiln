require "test_helper"
require "kiln/test_helper"

class Kiln::TestHelperTest < Kiln::TestCase
  include Kiln::TestHelper

  test "the dummy app builds repeatably" do
    kept = nil
    kiln_build(repeatable: true) do |output|
      kept = output
      assert output.join("index.html").file?
    end
    assert_not kept.exist?, "the temp dir is removed"
  end

  test "repeatable builds fail with the diff when the outputs differ" do
    runs = 0
    counter = ->(html) { html + "<!-- #{runs += 1} -->" }

    error = replace_method(Kiln::Processors::StripCSRF, :call, counter) do
      assert_raises(Minitest::Assertion) { kiln_build(repeatable: true) { flunk "must not yield" } }
    end
    assert_includes error.message, "~ index.html"
  end

  test "assert_page renders through the build pipeline" do
    body = assert_page "/about", selector: "h2#team", text: "Team"
    refute_includes body, "dev-panel"
    assert_page "/not-found", status: 404
  end

  test "assert_page fails on a missing selector" do
    assert_raises(Minitest::Assertion) { assert_page "/", selector: "h1", text: "Nope" }
  end
end
