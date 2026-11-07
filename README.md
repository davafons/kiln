<h1 align="center">Kiln</h1>

<p align="center">
  <a href="https://rubygems.org/gems/kiln"><img src="https://img.shields.io/gem/v/kiln?color=b45d3c" alt="Gem version"></a>
  <img src="https://img.shields.io/badge/ruby-4.0%2B-cc342d?logo=ruby&amp;logoColor=white" alt="Ruby 4.0+">
  <img src="https://img.shields.io/badge/rails-8.1%2B-d30001?logo=rubyonrails&amp;logoColor=white" alt="Rails 8.1+">
  <a href="https://github.com/davafons/kiln/actions/workflows/ci.yml"><img src="https://github.com/davafons/kiln/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center">
  Fire a Rails app into a static site.
</p>

<p align="center">
  <a href="#configuration">Configuration</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

Kiln renders every GET route of a Rails app through Rack and writes plain files that any static host can serve. You build pages with normal Rails: routes, controllers, views, helpers, Turbo and Stimulus. Development stays `bin/rails server`.

Routes are the page list. A route that needs params and has no param source fails the build, and every render error, missing asset and broken link is reported at once. Kiln knows nothing about your data: models and repositories stay ordinary app code.

## Build a site

```ruby
# Gemfile
gem "kiln"
```

```ruby
# config/kiln.rb
Kiln.configure do |config|
  config.url = "https://example.com"
  config.not_found = "/404"
end

Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
  skip :search, reason: "dynamic"
end
```

```sh
RAILS_ENV=production bin/rails kiln:build
```

The site lands in `dist/`. Kiln precompiles assets in-process, renders each page, exports the assets the pages reference, copies `public/`, and writes `_redirects`, `sitemap.xml` and `404.html`. Then it checks every internal link, anchor and importmap module, and exits non-zero on any problem.

## Declare the pages

A GET route with no required params is built automatically. A route with params needs a param source:

```ruby
Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
  params :page, -> { %w[en es ja].map { { locale: it } } + [ {} ] }  # scope "(:locale)"
  paginate :blog_page, per: 10, total: -> { Post.count }, start: 2  # /blog/page/2, /blog/page/3, ...
  skip :search, reason: "dynamic"
end
```

A route that needs params and has neither a param source nor a skip fails the build, and the error names the line to add. Rails internals, the health check, mounted engines and turbo-rails' native navigation routes are skipped by default. Redirect routes become redirects, and mounted Rack apps are built like any other route.

Feeds, `robots.txt`, `llms.txt` and JSON files are ordinary routes with views. The content type picks the extension, so `get "api"` rendering JSON is written as `api.json`.

## Develop and ship

Develop with `bin/rails server` and whatever reloading the app already has, such as Hotwire Spark. Kiln adds no dev server. It has two commands:

```sh
RAILS_ENV=production bin/rails kiln:build  # write the site; CI and deploys run this
bin/rails kiln:serve                       # look at the output as a static host serves it
```

`kiln:build` verifies every internal link, anchor and importmap module, and lists the pages that changed since the previous build. Set `VERBOSE=1` to see request logs. A repository that commits its output can check it in CI: run `kiln:build`, then fail if `git status --porcelain docs` prints anything.

`kiln:serve` uses Cloudflare Pages and GitHub Pages path resolution and applies `_redirects`. It reads `PORT` (default 4000) and `BIND` (default localhost).

## Configuration

| Option | Default | |
|---|---|---|
| `output` | `"dist"` | Relative to `Rails.root`, or absolute. Wiped at the start of every build. |
| `url` | `nil` | Public base URL, for the sitemap and absolute URLs. |
| `host` | from `url`, else `"localhost"` | Host header sent with every request. |
| `paths` | `:directory` | `/now` becomes `now/index.html`. `:file` writes `now.html`. |
| `assets` | `:referenced` | Assets the output references (HTML, importmap, CSS `url()`). `:all` exports everything. |
| `cname` | `nil` | Writes a `CNAME` file. |
| `not_found` | `nil` | Path rendered to `404.html`. It may respond with 200 or 404. |
| `redirects` | `:file` | `:file` (`_redirects`), `:meta_refresh` (HTML pages for GitHub Pages), `:both`, or `false`. |
| `sitemap` | `true` | Writes `sitemap.xml` when `url` is set. Pages marked `noindex` stay out. |
| `files` | `{}` | Files that aren't routes: `{ "octicons-license.txt" => "vendor/octicons/LICENSE" }`. |
| `strip_source_maps` | `true` | Removes `sourceMappingURL` comments from JS and CSS. |
| `absolute_urls` | `false` | Makes image URLs absolute (img, srcset, og: and twitter: images). |
| `external_links` | `false` | Adds `target="_blank" rel="noopener"` to links to other hosts. |
| `processors` | `[]` | Your HTML processors: `call(html, context)` returning a String. |
| `verify` | `true` | Runs the verifier after every build. |
| `verify_skip` | `[]` | CSS selectors for sample markup whose links aren't checked, such as `"[data-example-preview]"`. |
| `copy_public` | `true` | Copies `public/` (minus `public/assets`) into the output. |

Hooks receive a context with `output`, `env`, `manifest` and `report`:

```ruby
Kiln.configure do |config|
  config.before_build { |context| SearchIndex.generate! }
  config.after_build { |context| puts "#{context.manifest.entries.size} pages" }
end
```

CSRF tokens and meta tags are always stripped. The rest of the HTML stays byte for byte as the app rendered it.

## Write views for a build

- `Kiln.building?` is true while a build renders pages. Use it to hide development-only markup.
- `Kiln.build_cache.fetch(key) { ... }` memoizes for one build and is cleared before and after it.
- Builds fetch assets through the app, so keep `config.public_file_server.enabled = true` for the build environment.
- A build in development skips the precompile but still runs the steps hooked into `assets:precompile`, such as `tailwindcss:build`.
- Development middleware that injects markup (Hotwire Spark, web-console, rack-mini-profiler) fails the build. Load it only under `bin/rails server`.
- Root-absolute asset paths keep every page's `<head>` identical, so Turbo visits never force a full reload.

## Write in Markdown

The content layer is optional and works in server-rendered apps too. It needs commonmarker and Rouge:

```ruby
# Gemfile
gem "commonmarker"
gem "rouge"

# config/application.rb, after Bundler.require
require "kiln/content"
```

`app/views/pages/about.html.md` renders through the layout like any view, and `.md.erb` runs ERB first. commonmarker renders GitHub Flavored Markdown with tables, strikethrough, autolinks and heading ids; raw HTML passes through. Code blocks get Rouge CSS classes.

With `Kiln::Content.source_positions` on, each rendered block of a `.md` view or collection entry carries `data-tensaku-md="path:startLine:startCol-endLine:endCol"` for the Tensaku editor. The format is a draft. `.md.erb` views get none, because ERB shifts the line numbers. The setting defaults to on in development when Tensaku is loaded, and is always off while Kiln is building.

Collections read Markdown files with YAML frontmatter, such as `content/blog/2024-05-01-hello.md`:

```ruby
posts = Kiln::Content.collection("blog")
posts.all           # visible entries, newest first
posts.find("hello") # raises Kiln::Content::NotFound, which Rails maps to a 404
post.title, post.published_at, post.html, post[:tags]
```

Entries with `draft: true` or a future `published_at` are hidden, except in development when Kiln is not building. A server-rendered app can share a hidden entry with `posts.find(slug, preview_token: params[:token])`.

## Test the build

```ruby
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test("builds the same output twice") { assert_repeatable_build }
  test("home page") { assert_page "/", selector: "h1", text: "Welcome" }
end
```

`kiln_build { |output| ... }` builds into a temp dir, fails with the report on any error, and yields the output path.

## Known limits

- Pages render one at a time.
- Wildcard rules in your own `public/_redirects` are written out, but the verifier and `kiln:serve` only follow exact rules.
- JS modules are found through the importmap. Relative `import "./x.js"` between files is not followed.
- Collections read `*.md` files. `.md.erb` works for views only.

## Develop Kiln

```sh
bundle install
bin/test
bin/lint          # RuboCop and bin/house-rules
```

`test/dummy` is the Rails app the tests build. `bin/house-rules` rejects em dashes, AI attribution, leftover tool-call markup, filler phrases and dead links in Markdown. [AGENTS.md](AGENTS.md) holds the rules a script cannot check.

Releases publish from a `vX.Y.Z` tag that matches `Kiln::VERSION`. CI runs first, then the release workflow publishes to RubyGems through trusted publishing.

## License

Copyright © 2026 David Afonso. Kiln is licensed under the [MIT License](LICENSE).
