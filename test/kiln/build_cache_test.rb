require "test_helper"

class Kiln::BuildCacheTest < Kiln::TestCase
  test "returns the same object on every fetch" do
    cache = Kiln::BuildCache.new
    first = cache.fetch(:posts) { +"loaded" }
    assert_same first, cache.fetch(:posts) { flunk "block must not run twice" }
  end

  test "clear forgets everything" do
    cache = Kiln::BuildCache.new
    cache.write(:a, 1)
    cache.clear
    assert_nil cache.read(:a)
  end
end
