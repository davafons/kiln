# Writing views

Views for a Kiln site are ordinary Rails views. A build renders them through the app's full Rack stack, so helpers, layouts, partials and i18n behave as they do on a server. This page covers what is different about a build.

## Kiln.building?

`Kiln.building?` is true while a build renders pages. Use it to hide markup that only makes sense on a running server:

```erb
<% unless Kiln.building? %>
  <%= link_to "Edit this page", edit_page_path(@page) %>
<% end %>
```

It is also true inside `assert_page` from the [test helper](/testing/), so a test sees the page a build writes.

## Kiln.build_cache

`Kiln.build_cache.fetch(key) { ... }` memoizes a value for one build. The cache is cleared before and after every build, and it returns the cached object itself, not a copy:

```ruby
class Post
  def self.all
    Kiln.build_cache.fetch("posts") { load_posts_from_disk }
  end
end
```

Outside a build it runs the block every time, so a development server never serves stale data. The content layer caches collections in it during a build.

## Pages built from other pages

`Kiln.render(path)` returns another page's body as a build writes it, with CSRF tokens stripped. Use it for a page made from the others, such as a search index:

```ruby
# app/controllers/search_controller.rb
def index
  pages = Docs::PAGES.map do |page|
    html = Nokogiri::HTML5(Kiln.render(page_path(page.slug)))
    { url: page_path(page.slug), title: page.title, text: html.at_css("main").text.squish }
  end
  render json: pages
end
```

During a build the response is shared with the build itself, so each page is rendered once, whichever asks for it first. `/now` and `/now/` are the same page. Outside a build it renders on every call, so the route works on a development server too. A page that does not respond with 2xx raises `Kiln::Error`, and so does a page that renders itself, directly or through other pages. Kiln has no hook that runs after a build: a file made from other pages is a route like any other, and a step that is not Ruby (image generation with Node, for example) runs after `kiln:build` in your build script.

## Assets

A production build precompiles assets in-process into a temporary directory and exports them from there. `public/assets` is left alone, so a development server of the same app can run at the same time. Only the assets the output references are exported.

A build in development, where assets are served dynamically, skips the precompile but still runs the steps hooked into `assets:precompile`, such as `tailwindcss:build`, `javascript:build` and `css:build`. That way a development build never ships a stale bundle.

Propshaft only serves asset folders that exist when the app boots. Track `app/assets/builds/.keep`, as a new Rails app does, or a build on a fresh checkout stops with an error that says so.

Use the asset helpers (`stylesheet_link_tag`, `image_tag`, `javascript_importmap_tags`). They write root-absolute paths, which keep every page's `<head>` identical, so Turbo visits never force a full reload.

JavaScript modules are found through the importmap, and the link checker fails the build when a pinned module is missing from the output. Relative `import "./x.js"` between files is not followed.

## Development middleware

Development middleware that injects markup into every response fails the build before it renders anything: Hotwire Spark, web-console, rack-mini-profiler and rack-livereload. Load it only under `bin/rails server`:

```ruby
# config/application.rb, after Bundler.require
if Rails.env.development? && defined?(Rails::Server)
  require "action_cable/engine"
  require "hotwire-spark"
end
```

```ruby
# Gemfile
group :development do
  gem "hotwire-spark", require: false
end
```

This site loads Hotwire Spark that way, so `bin/rails server` reloads on every change and a build never sees it. Building with `RAILS_ENV=production` also avoids the problem.

## Editor markup

In-page editors add source-position attributes to the HTML: Herb's source attribution adds `data-herb-*`, [Tensaku](https://tensaku.lostcoords.com) adds `data-tensaku-*`, and the content layer adds `data-md-source` when `Kiln::Content.source_positions` is on. When any of them reaches a built page, the build fails with an error that lists the pages. Turn them off outside development, or build in production. The content layer turns its own attribute off while Kiln is building.

## Forms

CSRF tokens are stripped from every page, so a form renders as it would with forgery protection off. A static host has no server to post to: point forms at an external service, or skip their routes.
