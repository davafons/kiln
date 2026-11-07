require "test_helper"
require "kiln/test_helper"

class Kiln::TestHelperTest < Kiln::TestCase
  include Kiln::TestHelper

  test "the dummy app builds repeatably" do
    assert_repeatable_build
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
