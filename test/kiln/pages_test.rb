require "test_helper"

class Kiln::PagesTest < Kiln::TestCase
  setup { @pages = Kiln::Pages.new }

  test "params and skip are keyed by symbol" do
    source = -> { [] }
    @pages.params "post", source
    @pages.skip :search, reason: "dynamic"
    @pages.skip :up

    assert_equal({ post: source }, @pages.sources)
    assert_equal({ search: "dynamic", up: nil }, @pages.skips)
    assert_equal %i[post search up], @pages.declared_names
  end

  test "params needs a callable" do
    assert_raises(ArgumentError) { @pages.params :post, [ { slug: "a" } ] }
  end

  test "value lists build every combination and nil leaves the key out" do
    @pages.params :archive, locale: [ nil, "es" ], year: -> { [ 2025, 2026 ] }
    assert_equal [
      { year: 2025 }, { year: 2026 }, { locale: "es", year: 2025 }, { locale: "es", year: 2026 }
    ], @pages.sources[:archive].call
  end

  test "value lists are read at build time" do
    years = [ 2025 ]
    @pages.params :archive, year: -> { years }
    years << 2026
    assert_equal [ { year: 2025 }, { year: 2026 } ], @pages.sources[:archive].call
  end

  test "a source with value lists combines every source hash with every combination" do
    @pages.params :archive, -> { [ { year: 2025 }, { year: 2026 } ] }, locale: [ nil, "es" ]
    assert_equal [
      { year: 2025 }, { year: 2025, locale: "es" }, { year: 2026 }, { year: 2026, locale: "es" }
    ], @pages.sources[:archive].call
  end

  test "params needs a source or value lists" do
    assert_raises(ArgumentError) { @pages.params :post }
  end

  test "a value list may be a range, for pagination" do
    @pages.params :blog_page, page: -> { 2..25.fdiv(10).ceil }
    assert_equal [ { page: 2 }, { page: 3 } ], @pages.sources[:blog_page].call
  end
end
