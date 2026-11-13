# Views and assets

Views are ordinary Rails views. A build renders them through the app's full Rack stack, so helpers, layouts, partials and i18n behave as they do on a server. This page covers what is different during a build.

## Kiln.building?

`Kiln.building?` is true while a build renders pages. Use it to hide markup that only makes sense on a running server:

```erb
<% unless Kiln.building? %>
  <%= link_to "Edit this page", edit_page_path(@page) %>
<% end %>
```

It is also true inside `assert_page` from the [test helper](/testing/), so a test sees the page a build writes.

## Kiln.build_cache

`Kiln.build_cache.fetch(key) { ... }` keeps a value for one build, for data that many pages read:

```ruby
class Post
  def self.all
    Kiln.build_cache.fetch("posts") { load_posts_from_disk }
  end
end
```

The cache is cleared before and after every build, and it returns the cached object itself, not a copy. Outside a build it runs the block every time, so a development server never serves stale data.

## Kiln.render

`Kiln.render(path)` returns another page's body as a build writes it, with CSRF tokens stripped. Use it for a page made from other pages, such as a search index:

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

- During a build each page is rendered once, whichever asks for it first. Outside a build it renders on every call, so the route also works on a development server.
- `/now` and `/now/` are the same page.
- A page that does not respond with 2xx raises `Kiln::Error`. So does a page that renders itself, directly or through other pages.

Kiln has no hook that runs after a build. A file made from other pages is a route like any other. A step that is not Ruby, such as image generation with Node, runs after `kiln:build` in your build script.

## Assets

Use the asset helpers: `stylesheet_link_tag`, `image_tag` and `javascript_importmap_tags`. They write root-absolute paths, and Kiln finds the files from those references. Only the assets the output references are exported.

The build does one of two things, depending on the environment:

| Situation | What the build does |
|---|---|
| Production | Compiles into a temporary directory and ignores `public/assets`, so a stale compile never ships and a development server of the same app can run at the same time. |
| Development and test, where assets are served dynamically | Runs the tasks hooked into `assets:precompile`, such as `tailwindcss:build`, `javascript:build` and `css:build`, and exports from the running app. |

JavaScript modules are found through the importmap, and the build fails when a pinned module is missing from the output. Relative `import "./x.js"` between files is not followed.

`sourceMappingURL` comments are removed from exported JavaScript and CSS.

## Development middleware

Development middleware that injects markup into every response stops the build before it renders anything. That applies to Hotwire Spark, web-console, rack-mini-profiler and rack-livereload. Building with `RAILS_ENV=production` avoids the problem. To build in development too, load the gem only under `bin/rails server`:

```ruby
# Gemfile
group :development do
  gem "hotwire-spark", require: false
end
```

```ruby
# config/application.rb, after Bundler.require
if Rails.env.development? && defined?(Rails::Server)
  require "action_cable/engine"
  require "hotwire-spark"
end
```

## Editor markup

In-page editors add source-position attributes to the HTML: Herb's source attribution adds `data-herb-*`, [Tensaku](https://tensaku.lostcoords.com) adds `data-tensaku-*`, and the Markdown layer adds [`data-md-source`](/content/#source-positions) when it is on. The build fails when any of them reaches a page, and the error lists the pages. Turn them off outside development, or build in production.

## Forms

CSRF tokens and the `csrf-param` and `csrf-token` meta tags are stripped from every page, and the rest of the HTML stays byte for byte as the app rendered it. A form renders, but a static host has no server to post to. Point it at an external service, or skip its route.
