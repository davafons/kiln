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
  params :page, locale: [ nil, "es", "ja" ]                         # scope "(:locale)"
  params :archive, year: -> { Post.years }, locale: [ nil, "es" ]   # every combination
  paginate :blog_page, per: 10, total: -> { Post.count }, start: 2  # /blog/page/2, /blog/page/3, ...
  skip :search, reason: "dynamic"
end
```

A hash of value lists builds every combination of the values. A `nil` value leaves the key out, which fills an optional segment such as `(:locale)` with nothing. A list may be a lambda, called at build time.

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
| `url` | `nil` | Public base URL. Its host is sent with every request (`localhost` without it), and `sitemap.xml` is written only when it is set. |
| `paths` | `:directory` | `/now` becomes `now/index.html`. `:file` writes `now.html`. |
| `cname` | `nil` | Writes a `CNAME` file with this host. `true` takes the host from `url`. |
| `not_found` | `nil` | Path rendered to `404.html`. It may respond with 200 or 404. |
| `files` | `{}` | Files that aren't routes: `{ "octicons-license.txt" => "vendor/octicons/LICENSE" }`. |
| `verify_skip` | `[]` | CSS selectors for sample markup whose links aren't checked, such as `"[data-example-preview]"`. |

Every build exports the assets the output references (HTML, importmap, CSS `url()`), removes `sourceMappingURL` comments from JS and CSS, copies `public/` (minus `public/assets`), writes `_redirects` when a route redirects, and runs the verifier. The sitemap leaves out pages marked `noindex`.

CSRF tokens and meta tags are always stripped. The rest of the HTML stays byte for byte as the app rendered it.

## Write views for a build

- `Kiln.building?` is true while a build renders pages. Use it to hide development-only markup.
- `Kiln.build_cache.fetch(key) { ... }` memoizes for one build and is cleared before and after it. Outside a build it runs the block every time, so a development server never serves stale data.
- A production build precompiles assets into a temporary directory and exports them from there. `public/assets` is left alone, so a development server of the same app can run at the same time.
- Propshaft only serves asset folders that exist when the app boots. Track `app/assets/builds/.keep`, as a new Rails app does, or the build stops with an error on a fresh checkout.
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

`Kiln::Content::Markdown.render(text)` returns HTML. `Kiln::Content::Markdown.render_inline(text)` drops the `<p>` around text that is a single paragraph, for titles and captions; other text renders as with `render`.

With `Kiln::Content.source_positions` on, each rendered block of a `.md` view or collection entry carries `data-tensaku-md="path:startLine:startCol-endLine:endCol"` for the Tensaku editor. The format is a draft. `.md.erb` views get none, because ERB shifts the line numbers. The setting defaults to on in development when Tensaku is loaded, and is always off while Kiln is building.

Collections read Markdown files with YAML frontmatter, such as `content/blog/2024-05-01-hello.md`:

```ruby
posts = Kiln::Content.collection("blog")
posts.all           # visible entries, newest first
posts.find("hello") # raises Kiln::Content::NotFound, which Rails maps to a 404
post.title, post.published_at, post.html, post[:tags]
```

A filename date may be `YYYY-MM-DD` or `YYYY-MM`. A month-only date sets `published_at` to the 1st of that month, and a filename that is only a date, such as `2026-08.md`, keeps the date as its slug.

`SLUG.LOCALE.md` is a translation of the entry with that slug, such as `2026-08.es.md` for `2026-08.md`. A locale is two lowercase letters, optionally followed by a dash and two uppercase letters (`es`, `pt-BR`). Translations stay out of `all`, `find` and `each`:

```ruby
post.locale            # nil for SLUG.md, "es" for SLUG.es.md
post.translation(:es)  # the visible SLUG.es.md entry, or nil
```

A translation whose entry does not exist fails when the collection loads.

Entries with `draft: true` or a future `published_at` are hidden, except in development when Kiln is not building.

## Test the build

```ruby
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "the site builds repeatably" do
    kiln_build(repeatable: true) { |output| assert output.join("index.html").file? }
  end

  test("home page") { assert_page "/", selector: "h1", text: "Welcome" }
end
```

`kiln_build { |output| ... }` builds into a temp dir, fails with the report on any error, and yields the output path. With `repeatable: true` it builds twice, fails with the list of differing files when the outputs differ, and yields the first output.

## Known limits

- Pages render one at a time.
- Redirects are written only as `_redirects`, which Cloudflare Pages and Netlify read. GitHub Pages ignores the file, so redirect routes do not redirect there.
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
