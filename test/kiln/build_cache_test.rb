require "test_helper"

class Kiln::BuildCacheTest < Kiln::TestCase
  test "returns the same object on every fetch during a build" do
    Kiln.building! do
      first = Kiln.build_cache.fetch(:posts) { +"loaded" }
      assert_same first, Kiln.build_cache.fetch(:posts) { flunk "block must not run twice" }
    end
  end

  test "runs the block every time outside a build" do
    runs = 0
    2.times { Kiln.build_cache.fetch(:posts) { runs += 1 } }
    assert_equal 2, runs
  end

  test "builds start with an empty cache" do
    Kiln.building! { Kiln.build_cache.fetch(:a) { 1 } }
    Kiln.building! { assert_equal 2, Kiln.build_cache.fetch(:a) { 2 } }
  end
end
