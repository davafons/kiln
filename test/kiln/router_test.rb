require "test_helper"

class Kiln::RouterTest < Kiln::TestCase
  class Engine < Rails::Engine; end

  setup do
    @report = Kiln::Report.new
    @pages = Kiln::Pages.new
  end

  test "builds GET routes without required params, redirects and mounted rack apps" do
    router = router_for do
      root "pages#home"
      get "about", to: "pages#about", as: :about
      post "contact", to: "pages#contact"
      get "old", to: redirect("/about"), as: :old
      mount ->(env) { [ 200, {}, [] ] }, at: "/ping.txt"
    end

    assert_equal %w[/ /about /old /ping.txt], router.pages.map(&:path)
    assert_equal [ "root", "about", "old", nil ], router.pages.map(&:route_name)
    assert @report.success?
  end

  test "skips internal routes, the health check and engines by default" do
    router = router_for do
      get "rails/info", to: "rails/info#index"
      get "up", to: "rails/health#show", as: :rails_health_check
      mount Engine, at: "/admin"
      get "about", to: "pages#about", as: :about
    end

    assert_equal %w[/about], router.pages.map(&:path)
    assert_equal [ "Rails internal route", "Rails health check", "mounted engine", nil ], router.rows.map(&:reason)
    assert @report.success?
  end

  test "expands param sources, escaping values through to_param" do
    post = Struct.new(:slug) { def to_param = slug }
    @pages.params :post, -> { [ { slug: post.new("hello") }, { "slug" => "a b/c" }, { slug: 2 } ] }
    router = router_for { get "posts/:slug", to: "posts#show", as: :post }

    assert_equal %w[/posts/hello /posts/a%20b%2Fc /posts/2], router.pages.map(&:path)
    assert_equal({ slug: "a b/c" }, router.pages[1].params)
    assert_equal [ Kiln::Router::Row.new(name: "post", path: "/posts/:slug(.:format)", status: :built, count: 3, reason: nil) ], router.rows
  end

  test "optional segments are left out unless the source supplies them" do
    @pages.params :about, -> { [ {}, { locale: "es" }, { locale: "ja" } ] }
    router = router_for do
      scope "(:locale)" do
        get "about", to: "pages#about", as: :about
        get "now", to: "pages#now", as: :now
      end
    end

    assert_equal %w[/about /es/about /ja/about /now], router.pages.map(&:path)
  end

  test "glob params keep slashes" do
    @pages.params :doc, -> { [ { path: "guides/intro" } ] }
    router = router_for { get "docs/*path", to: "docs#show", as: :doc }
    assert_equal %w[/docs/guides/intro], router.pages.map(&:path)
  end

  test "dedupes paths, first route wins" do
    router = router_for do
      get "about", to: "pages#about", as: :about
      get "about", to: "pages#other", as: :about_again
    end

    assert_equal [ "about" ], router.pages.map(&:route_name)
    assert_equal [ 1, 0 ], router.rows.map(&:count)
  end

  test "explicit skip wins over building" do
    @pages.skip :private_page, reason: "secret"
    @pages.skip :search
    router = router_for do
      get "private", to: "pages#private_page", as: :private_page
      get "search/:q", to: "pages#search", as: :search
    end

    assert_empty router.pages
    assert_equal [ "secret", "skipped in config/kiln.rb" ], router.rows.map(&:reason)
    assert @report.success?
  end

  test "routes with required params and no source are uncovered" do
    router = router_for do
      get "posts/:slug", to: "posts#show", as: :post
      get "tags/:tag", to: "tags#show"
    end

    assert_empty router.pages
    assert_equal %i[uncovered uncovered], router.rows.map(&:status)
    named, unnamed = @report.errors
    assert_equal :uncovered_route, named.kind
    assert_includes named.message, "/posts/:slug(.:format)"
    assert_includes named.message, "params :post, -> { [ { slug: ... } ] }"
    assert_includes named.message, "skip :post"
    assert_includes unnamed.message, "/tags/:tag(.:format)"
    assert_includes unnamed.message, "as:"
  end

  test "declarations for unknown routes are errors" do
    @pages.params :psot, -> { [] }
    @pages.skip :serach
    @pages.skip :contact
    router_for { post "contact", to: "pages#contact", as: :contact }.pages

    assert_equal [ :other ] * 3, @report.errors.map(&:kind)
    assert_includes @report.errors.first.message, ":psot"
  end

  test "bad param sources are reported and the build keeps going" do
    @pages.params :raises, -> { raise "boom" }
    @pages.params :hash, -> { { slug: "a" } }
    @pages.params :items, -> { [ "a", { slug: "ok" } ] }
    @pages.params :missing, -> { [ { slg: "a" }, { slug: nil } ] }
    router = router_for do
      get "raises/:slug", to: "a#show", as: :raises
      get "hash/:slug", to: "a#show", as: :hash
      get "items/:slug", to: "a#show", as: :items
      get "missing/:slug", to: "a#show", as: :missing
      get "about", to: "pages#about", as: :about
    end

    assert_equal %w[/items/ok /about], router.pages.map(&:path)
    messages = @report.errors.map(&:message)
    assert_equal 5, messages.size
    assert_equal [ :other ], @report.errors.map(&:kind).uniq
    assert_match(/:raises raised RuntimeError: boom/, messages[0])
    assert_match(/:hash must return a list/, messages[1])
    assert_match(/:items returned "a"/, messages[2])
    assert_match(/:missing .*missing :slug/, messages[3])
    assert_match(/:missing .*missing :slug/, messages[4])
  end

  test "paginate through the router" do
    @pages.paginate :posts_page, per: 10, total: -> { 15 }, start: 2
    router = router_for do
      get "posts", to: "posts#index", as: :posts
      get "posts/page/:page", to: "posts#index", as: :posts_page
    end

    assert_equal %w[/posts /posts/page/2], router.pages.map(&:path)
  end

  test "dummy app: every GET route is built or skipped" do
    router = Kiln::Router.new(dummy_app.routes, Kiln.pages, report: @report)

    assert @report.success?, @report.to_s
    assert_not router.rows.any? { it.status == :uncovered }
    paths = router.pages.map(&:path)
    %w[/ /about /posts /posts/hello-world /posts/second-post /feed.xml /health.json /old-about /ping.txt /not-found /contact /es/contact /ja/contact].each do
      assert_includes paths, it
    end
    assert_not_includes paths, "/search"
    assert_not_includes paths, "/up"
    assert_equal paths.uniq, paths
  end

  test "dummy app: turbo-rails native navigation routes are skipped" do
    router = Kiln::Router.new(dummy_app.routes, Kiln.pages, report: @report)
    turbo = router.rows.select { it.name.to_s.start_with?("turbo_") }

    assert_equal %w[/recede_historical_location(.:format) /resume_historical_location(.:format) /refresh_historical_location(.:format)], turbo.map(&:path)
    assert_equal [ [ :skipped, "turbo-rails native navigation" ] ] * 3, turbo.map { [ it.status, it.reason ] }
  end

  private
    def router_for(&routes)
      set = ActionDispatch::Routing::RouteSet.new
      set.draw(&routes)
      Kiln::Router.new(set, @pages, report: @report)
    end
end
