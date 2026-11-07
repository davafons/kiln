# Kiln

Kiln fires a Rails app into a static site. Build pages with normal Rails (routes, controllers, views,
helpers, Turbo, Stimulus), then run:

```sh
RAILS_ENV=production bin/rails kiln:build
```

Kiln renders every GET route through Rack, the same way a browser request goes through your app,
and writes plain files to `dist/` that any static host can serve.

- **Routes are the page list.** A GET route with no params is built automatically. A route with
  params needs a param source or an explicit `skip`, or the build fails and names it.
- **Builds fail loudly.** Every render error, missing asset and broken link is collected and printed
  as one report, and the task exits non-zero.
- **Kiln knows nothing about your data.** Models and repositories stay ordinary app code.

Requires Ruby 4.0+ and Rails 8.1+.

Releases: push a `vX.Y.Z` tag matching `Kiln::VERSION`. CI runs, then the release workflow publishes
to RubyGems through trusted publishing.

## Setup

```ruby
# Gemfile
gem "kiln"
```

```ruby
# config/kiln.rb
Kiln.configure do |config|
  config.url = "https://example.com"   # sitemap, absolute URLs, request host
  config.not_found = "/404"            # rendered to 404.html
end

Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
  params :page, -> { %w[en es ja].map { { locale: it } } + [ {} ] }  # scope "(:locale)"
  paginate :blog_page, per: 10, total: -> { Post.count }, start: 2  # /blog/page/2 ...
  skip :search, reason: "dynamic"
end
```

`bin/rails kiln:routes` shows every GET route and whether it is built, skipped or uncovered.

Rails internals (`/rails/*`), the health check, mounted engines and turbo-rails' native navigation
routes are skipped by default. Redirect routes become redirects, and mounted Rack apps are built
like any other route.

## Tasks

| Task | What it does |
|---|---|
| `kiln:build` | Renders every page, exports assets, copies `public/`, writes redirects, sitemap and manifest, then verifies the output. Lists pages changed since the last build. `VERBOSE=1` shows request logs. |
| `kiln:routes` | The route table. Exits 1 if any route is uncovered. |
| `kiln:verify` | Checks internal links, anchors and importmap modules in the existing output. |
| `kiln:check` | Builds into a temp dir and fails if the committed output differs. For CI. |
| `kiln:serve` | Serves the output with static-host path resolution (`PORT`, default 4000). |

## Configuration

| Option | Default | |
|---|---|---|
| `output` | `"dist"` | Relative to `Rails.root`, or absolute. Wiped at the start of every build. |
| `url` | `nil` | Public base URL. Needed for the sitemap and `absolute_urls`. |
| `host` | from `url`, else `"localhost"` | Host header sent with every request. |
| `paths` | `:directory` | `/now` → `now/index.html`. `:file` writes `now.html`. |
| `assets` | `:referenced` | Only assets the output references (HTML, importmap, CSS `url()`). `:all` exports everything. |
| `cname` | `nil` | Writes a `CNAME` file. |
| `not_found` | `nil` | Path rendered to `404.html`. It may respond with 200 or 404. |
| `redirects` | `:file` | `:file` (`_redirects`), `:meta_refresh` (HTML pages, for GitHub Pages), `:both`, or `false`. |
| `sitemap` | `true` | Writes `sitemap.xml` (needs `url`). Pages marked `noindex` are left out. |
| `strip_source_maps` | `true` | Removes `sourceMappingURL` comments from JS and CSS. |
| `absolute_urls` | `false` | Makes image URLs (img, srcset, og:/twitter: images) absolute. |
| `external_links` | `false` | Adds `target="_blank" rel="noopener"` to links to other hosts. |
| `processors` | `[]` | Your own HTML processors: `call(html, context)` returning a String. |
| `verify` | `true` | Runs the verifier after every build. |
| `copy_public` | `true` | Copies `public/` (minus `public/assets`) into the output. |

Hooks get a context with `output`, `env`, `manifest` and `report`:

```ruby
Kiln.configure do |config|
  config.before_build { |context| SearchIndex.generate! }
  config.after_build { |context| puts "#{context.manifest.entries.size} pages" }
end
```

CSRF tokens and meta tags are always stripped. Everything else in the HTML is left byte for byte as
the app rendered it.

## In your app

- `Kiln.building?` is true while a build renders pages. Use it to hide dev-only things.
- `Kiln.build_cache.fetch(key) { ... }` memoizes for one build and is cleared before and after.
- Builds run in production. Kiln runs `assets:precompile` in-process when needed and removes
  `public/assets` afterwards. Assets are fetched through the app, so keep
  `config.public_file_server.enabled = true` for builds.
- Use root-absolute asset paths so every page's `<head>` stays identical and Turbo visits never
  force a full reload.
- Feeds, `robots.txt`, `llms.txt` or JSON files are ordinary routes with views
  (`get "feed.xml"`). The file is written under the route's path.

## Testing

```ruby
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test("builds the same output twice") { assert_repeatable_build }
  test("home page") { assert_page "/", selector: "h1", text: "Welcome" }
end
```

`kiln_build { |output| ... }` builds into a temp dir, fails with the report on any error and
yields the output path.

## Content layer

Optional, and it works in server-rendered apps too:

```ruby
# Gemfile
gem "redcarpet"
gem "rouge"

# config/application.rb, after Bundler.require
require "kiln/content"
```

- **Markdown views:** `app/views/pages/about.html.md` renders through the layout like any view.
  `.md.erb` runs ERB first. Code blocks get Rouge CSS classes (`rougify style github`).
- **Collections:** `content/blog/2024-05-01-hello.md` with YAML frontmatter.

  ```ruby
  posts = Kiln::Content.collection("blog")
  posts.all                     # visible entries, newest first
  posts.find("hello")           # raises Kiln::Content::NotFound (a 404)
  post.title, post.published_at, post.html, post[:tags]

  # config/kiln.rb
  params :post, -> { Kiln::Content.collection("blog").map { { slug: it.slug } } }
  ```

- **Publishing:** `draft: true` and future `published_at` entries are hidden, except in
  development when not building. `Kiln::Content.show_drafts` overrides this. Server-rendered apps
  can share a hidden entry with `posts.find(slug, preview_token: params[:token])`.

## Limitations in 0.1

- Pages render one at a time. Parallel rendering is planned.
- Only exact `_redirects` rules count for the verifier and `kiln:serve`. Splat and placeholder
  rules in your own `public/_redirects` are written out but not followed.
- JS modules are found through the importmap. Relative `import "./x.js"` between files is not
  followed.
- Collections read `*.md` files only (`.md.erb` works for views).

## License

MIT. See [LICENSE](LICENSE).
