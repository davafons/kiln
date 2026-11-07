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

  test "params takes a source or value lists, not both" do
    assert_raises(ArgumentError) { @pages.params :post, -> { [] }, slug: [ "a" ] }
  end

  test "paginate builds start through the last page" do
    @pages.paginate :posts_page, per: 10, total: -> { 25 }
    assert_equal [ { page: 1 }, { page: 2 }, { page: 3 } ], @pages.sources[:posts_page].call
  end

  test "paginate always builds the start page" do
    @pages.paginate :posts_page, per: 10, total: -> { 0 }, param: :n, start: 2
    assert_equal [ { n: 2 } ], @pages.sources[:posts_page].call
  end

  test "paginate with a custom start" do
    @pages.paginate :posts_page, per: 5, total: -> { 11 }, start: 2
    assert_equal [ { page: 2 }, { page: 3 } ], @pages.sources[:posts_page].call
  end

  test "paginate rejects a non-positive per" do
    assert_raises(ArgumentError) { @pages.paginate :posts_page, per: 0, total: -> { 1 } }
  end
end
