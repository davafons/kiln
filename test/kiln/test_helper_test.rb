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

  test "kiln_site builds once for every test in the class" do
    builds = 0
    counting = ->(html) { builds += 1 if html.include?("<h1>Home</h1>"); html }
    site = replace_method(Kiln::Processors::StripCSRF, :call, counting) do
      kiln_site.tap { assert_equal it, self.class.new("another test").kiln_site }
    end

    assert_equal 1, builds
    assert site.join("index.html").file?
  ensure
    Kiln::TestHelper::SITES.clear
  end

  test "kiln_site fails every caller with the report when the build fails" do
    pages = Kiln::Pages.new
    errors = replace_method(Kiln, :pages, -> { pages }) do
      2.times.map { assert_raises(Minitest::Assertion) { kiln_site } }
    end

    assert errors.all? { it.message.include?("Uncovered route") }
    assert_equal 1, Kiln::TestHelper::SITES.size
  ensure
    Kiln::TestHelper::SITES.clear
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
