# Kiln — plan

Kiln fires a Rails app into a static site. You build pages with normal Rails (routes, controllers,
views, helpers, Turbo, Stimulus). `bin/rails kiln:build` renders every page through the app and writes
plain files that any static host can serve.

Status: phases 0–4 implemented (0.1.0 candidate). Phases 5–6 happen in the lostcoords-ui and davafons.com repos.

## Why

Three existing pieces each solve part of the problem:

| Source | What it is | Problem |
|---|---|---|
| [Perron](https://github.com/Rails-Designer/perron) 1.2.0 | Rails engine. Finds pages from `content/` routes, dispatches controllers directly, writes `output/`. | Render errors are printed and skipped, and the build still exits 0. `content/` namespace convention. Precompiles assets in a subprocess with output hidden. Removes Turbo from the build by default. One maintainer. |
| `lostcoords-ui` `test/dummy/lib/tasks/showcase.rake` | Crawls the docs app with `ActionDispatch::Integration::Session`, saves the HTML and referenced assets. | Page list is hardcoded and separate from `routes.rb`. Uses test-only Rails code. Not reusable. |
| `davafons.com` `app/{dsl,generators}` | Rails-free generator: `Pages` DSL, `SiteBuilder`, `ViewContext`, custom dev server. | About 1,000 lines that rebuild Rails piece by piece, all tied to one site. |

Kiln keeps the good ideas from each and owns none of the app's data or content model.

## Core decisions

### 1. Render through Rack, not by dispatching controllers or using an integration session

```ruby
response = Rack::MockRequest.new(Rails.application).get(path, "HTTP_HOST" => host, "HTTPS" => "on")
```

- **Perron** (`controller.dispatch(action, request, response)`) skips the middleware stack. Anything an
  app does in middleware (locale, host checks, `ActionDispatch::Static`, custom Rack apps mounted in
  routes, redirect routes) behaves differently at build time than under `rails server`. It also
  re-implements route recognition and instantiates controllers by name. Direct dispatch saves only a few
  microseconds per page.
- **lostcoords-ui** (`ActionDispatch::Integration::Session`) runs the full stack, but it is test
  infrastructure: a cookie jar, `assert_*` plumbing, `action_dispatch/testing` loaded in production builds.
- **Rack call:** runs the full stack and loads no test code. The app behaves at build time exactly as
  it does in the browser. Redirect routes and mounted Rack apps (for example a `/health.json` endpoint)
  work automatically.

### 2. Routes are the single source of truth, and every GET route must be accounted for

- A GET route with no required params is built automatically. Perron does this only for `root_path` and
  an `additional_routes` list.
- A GET route with params needs a **param source**, declared once (in `config/kiln.rb`):

  ```ruby
  Kiln.pages do
    params :post, -> { Post.published.map { { slug: it.slug } } }
    params :now_archive, -> { NowEntry.all.map { { year: it.year, month: it.month } } }
    skip :up                           # rails health check
    skip :search, reason: "dynamic"
  end
  ```

- **Coverage check:** if a GET route has neither a param source nor a `skip`, the build fails and names
  the route. Perron silently ignores routes it doesn't understand. lostcoords-ui forgets pages when the
  rake list drifts from `routes.rb`.
- Engine routes, Rails internal routes (`/rails/*`) and the health check are skipped by default.

### 3. Fail loudly, and report every failure at once

Any non-2xx response that isn't a declared redirect, a missing asset, a broken internal link, or a route
with no coverage fails the build. Errors are collected across the whole run and printed as one report,
then the task exits with a non-zero status. This is the opposite of Perron's `rescue => error; puts`.

### 4. Kiln knows nothing about the app's data

No models, data sources or collections in the core. Your repositories (davafons.com's
`HealthRepository`, `PostRepository`, ...) stay ordinary app code. The optional content layer (phase 4)
covers Markdown with frontmatter because nearly every static site needs it.

## Features by source

✅ take · 🔧 take with changes · ❌ leave out

### From Perron

| Feature | | Notes |
|---|---|---|
| Find pages from Rails routes | 🔧 | All GET routes, not only `content/*` index/show. Param sources replace collection guessing. |
| Directory output (`/now/` → `now/index.html`) | 🔧 | Default. `:file` mode (`/components` → `components.html`) for lostcoords-ui. |
| `before_build` / `after_build` hooks | ✅ | Context exposes the output path, env and page manifest. |
| Preview server for the built output | ✅ | `kiln:serve` uses the same path resolution as Cloudflare Pages / GitHub Pages, so you test what you ship. |
| HTML post-processors | 🔧 | Applied to every HTML response, not only Markdown. Built in: strip CSRF tokens. Optional: absolute image URLs, `target=_blank` on external links. |
| Sitemap | 🔧 | Built from the set of pages actually written, not re-derived from routes. Skips pages marked `noindex`. |
| Pagination paths (`/blog/page/2/`) | 🔧 | A param-source helper: `paginate :posts, per: 10, total: -> { Post.count }`. |
| Drafts, scheduled posts, preview tokens | ✅ | Content layer (phase 4). |
| Integrated mode (static pages written into `public/` of a dynamic app) | ❌ | Apps with a server already get static-like delivery from HTTP caching behind a CDN (wariwari: `cache_public_page` + Cloudflare, blog posts in the database). Kiln is for sites with no server. `output` stays configurable. |
| `.md` / `.erb` content collections | 🔧 | Content layer. A `.md` template handler for ActionView, so Markdown is just another view format. |
| YAML/JSON/CSV data sources | ❌ | App code. `YAML.load_file` is one line. |
| `content/` namespace convention | ❌ | Explicit declarations instead. |
| Silent page failures | ❌ | See decision 3. |
| `assets:precompile` subprocess with output hidden | ❌ | Assets run in-process, errors visible. |
| Turbo in `excluded_assets` by default | ❌ | Kiln leaves your JavaScript alone. |
| Live reload (Mata) | ❌ | Dev is `rails server`. Use hotwire-spark or nothing. |
| Feed builder (RSS/Atom/JSON) | ❌ | Feeds are ordinary routes with `.xml` / `.json` views. |
| Deploy tasks, dev "concierge" controller | ❌ | Deploying is the host's job. The concierge passes request params to `system` in development. |

### From lostcoords-ui (`showcase.rake`, `static_export_test.rb`)

| Feature | | Notes |
|---|---|---|
| Find assets from HTML `href`/`src` and the importmap | ✅ | Plus `url(...)` inside CSS, so fonts and images referenced from stylesheets come along. `assets: :referenced` (default) or `:all`. |
| Fetch assets through the app | ✅ | Propshaft serves `/assets/*` in dev; `ActionDispatch::Static` serves `public/assets` after a precompile. Same code path either way. |
| Root-absolute asset paths | ✅ | Every page's tracked `<head>` stays identical, so Turbo visits never trigger a full reload. Documented, not enforced. |
| Strip `authenticity_token` inputs | ✅ | Built-in processor. Also drops the `csrf-token` meta tags. |
| Strip `sourceMappingURL` comments | ✅ | Option, on by default. |
| Fail on non-success responses | ✅ | |
| Check internal links, anchors and importmap modules | ✅ | Runs after every build (`kiln:verify` runs it alone). |
| Repeatable output (export twice, compare) | ✅ | `Kiln::TestHelper#assert_repeatable_build`. |
| CI check that committed output is current | ✅ | `kiln:check` builds into a temp dir and diffs against the committed output. Replaces the `git diff --exit-code docs/` step. |
| Extra files (`CNAME`, `llms.txt`, `search.json`, `api.json`) | 🔧 | Routes for generated files. `config.cname` for the one-liner. |
| Hardcoded page list | ❌ | Decision 2. |
| `Integration::Session` | ❌ | Decision 1. |

### From davafons.com

| Feature | | Notes |
|---|---|---|
| `Pages` DSL (route list = page list) | 🔧 | Becomes `Kiln.pages` param sources plus the coverage check, sitting on top of `routes.rb`. |
| Markdown pipeline (Redcarpet + Rouge, YAML frontmatter) | ✅ | Content layer: `.md` handler + frontmatter loader, based on `app/generators/markdown_processor.rb`. |
| Per-build cache reset (`reset_cache!` on every repository) | 🔧 | `Kiln.build_cache` (cleared per build) or `ActiveSupport::CurrentAttributes`. Repositories memoize inside a build and reload between dev requests. |
| Localized variants (`/es/now`, `/ja/health`) | 🔧 | Rails `scope "(:locale)"` plus a param source returning each locale. |
| Generated JSON (`/health.json`) | 🔧 | A route with a JSON view. Nothing special in Kiln. |
| RSS and sitemap views | 🔧 | RSS stays a route. Sitemap moves to Kiln (generated from the page manifest). |
| `bin/server` (rebuild on change, live reload, location Worker proxy) | ❌ | `rails server`. The location proxy becomes a dev-only route or a Parcela service. |
| Custom `ViewContext`, file reloading | ❌ | Rails does this. |

### New in Kiln (none of the three have these)

- **Route coverage check** (decision 2).
- **One error report for the whole build** (decision 3).
- **Redirects:** `redirect(...)` routes and 301/302 responses become a `_redirects` file (Cloudflare
  Pages, Netlify), with optional meta-refresh HTML for GitHub Pages.
- **404 page:** render a configured route to `404.html`.
- **Page manifest:** `kiln-manifest.json` maps each path to its content digest. Used by the sitemap, by
  `kiln:check`, and to print which pages changed in a build.
- **`Kiln.building?`** so views can hide dev-only things (debug panels, local proxies).
- **Parallel rendering** with a thread pool (later, behind a flag; Rails apps are thread-safe through
  the executor).

## Shape

```
config/kiln.rb          Kiln.configure { ... } and Kiln.pages { ... }
lib/kiln.rb             entry point, configuration
lib/kiln/railtie.rb     loads config/kiln.rb, rake tasks, host allowance during builds
lib/kiln/pages.rb       DSL: params, paginate, skip
lib/kiln/router.rb      walks Rails routes, expands param sources, coverage check
lib/kiln/renderer.rb    Rack::MockRequest against Rails.application
lib/kiln/writer.rb      path → file mapping (:directory / :file), content-type aware
lib/kiln/assets.rb      collects referenced assets (HTML, importmap, CSS url()), fetches through Rack
lib/kiln/processors/    strip_csrf, strip_source_maps, absolute_urls, external_links
lib/kiln/verifier.rb    internal links, anchors, importmap modules
lib/kiln/sitemap.rb     sitemap.xml from the manifest
lib/kiln/redirects.rb   _redirects and meta-refresh pages
lib/kiln/manifest.rb    path → digest, diffing
lib/kiln/server.rb      kiln:serve, static-host path resolution
lib/kiln/report.rb      collected errors and summary
lib/kiln/content/       phase 4: .md handler, frontmatter, collections, publishing
test/dummy/             Rails app used by the test suite
```

Rake tasks: `kiln:build`, `kiln:serve`, `kiln:verify`, `kiln:check`, `kiln:routes` (shows every GET
route and whether it is built, skipped, or uncovered).

Build pipeline:

```
before_build hook
→ router: GET routes × param sources → page list (fails on uncovered routes)
→ renderer: each path through Rack → status, headers, body
→ processors: HTML transforms
→ writer: files under output/ (+ redirects, 404)
→ assets: referenced /assets/* → output/assets
→ public/: copy (minus assets/)
→ sitemap, CNAME, manifest
→ verifier: links, anchors, importmap
→ report (non-zero exit on any failure)
→ after_build hook
```

## Work list

### Phase 0 — workspace

- [x] Gem skeleton: `kiln.gemspec`, `lib/kiln.rb`, version, MIT license, README.
- [x] `test/dummy` Rails 8.1 app with Propshaft and importmap, plus a Minitest setup.
- [x] Lint (rubocop-rails-omakase, like lostcoords-ui) and GitHub Actions CI.
- [x] jj repo, colocated.
- [x] Claim the `kiln` name on RubyGems (published 0.1.0 directly through trusted publishing, no placeholder).

### Phase 1 — core build

- [x] Configuration (`output` = `dist`, `host`, `url`, `paths: :directory | :file`, `assets`, `cname`).
- [x] `Kiln.pages` DSL and router with the coverage check.
- [x] Renderer (Rack), writer, content-type → extension mapping.
- [x] Asset collection and fetching through Rack, `public/` copy.
- [x] CSRF and source-map processors.
- [x] Error report and exit status.
- [x] `kiln:build`, `kiln:routes`.

### Phase 2 — verification

- [x] Verifier: internal links, anchors, importmap modules (ported from `static_export_test.rb`).
- [x] `kiln:check` (committed output is current).
- [x] `Kiln::TestHelper` with `assert_repeatable_build` and `assert_page`.
- [x] `kiln:serve`.

### Phase 3 — extras

- [x] Sitemap from the manifest, `noindex` handling.
- [x] Redirects (`_redirects`, meta refresh), 404 page.
- [x] Hooks, custom processors, manifest diff output.
- [x] `paginate` param-source helper.

### Phase 4 — content layer (optional require: `kiln/content`)

- [x] `.md` template handler (Redcarpet + Rouge), `.md.erb`.
- [x] Frontmatter loader and a small collection API (`Kiln::Content.collection("blog")`).
- [x] Drafts, scheduled posts (`published_at` in the future), preview tokens.

### Phase 5 — lostcoords-ui docs on Kiln

- [ ] Add Kiln to the dummy app, `paths: :file`, `cname: "ui.lostcoords.com"`.
- [ ] Param sources for `component`, `block`, `block_preview`.
- [ ] Delete `showcase.rake`. Swap the CI staleness step for `kiln:check`.
- [ ] `static_export_test.rb` keeps the docs-specific assertions (API counts, search anchors). The
      generic checks move to Kiln.
- [ ] The committed `docs/` export must be byte-identical before and after.

### Phase 6 — davafons.com on Rails + Kiln

- [ ] Rails 8.1 skeleton in place (no Active Record, no Action Cable, no Active Storage).
- [ ] Routes for every page in `config/pages.rb` (en/es/ja variants, now archives, blog, tags, photos,
      map, health, projects, about).
- [ ] Controllers that call the existing repositories. Move `app/{models,repositories,clients}` under
      Zeitwerk.
- [ ] Helpers: drop `ViewContext`; move `LocalizationHelper` / `HealthTranslations` strings to
      `config/locales/{en,es,ja}.yml` and call `t(...)`.
- [ ] Views mostly unchanged. `lc_*` helpers work through the lostcoords-ui Rails engine.
- [ ] Assets: Propshaft + importmap; vendor Leaflet, uPlot, h3-js, turf as ES modules. Tailwind
      through tailwindcss-rails.
- [ ] `health.json`, RSS, sitemap, robots, 404 as routes or Kiln config.
- [ ] Dev: `rails server` in `parcela.yaml`; location Worker proxy as a dev-only route.
- [ ] `bin/build`, `bin/ci`, `pages-deploy.yml` call `RAILS_ENV=production bin/rails kiln:build` and
      deploy `dist/`.
- [ ] Compare old and new builds page by page (HTML diff after normalizing) before switching.
- [ ] Delete `app/dsl`, `app/generators`, `bin/server`, `bin/ui-stylesheet`, `bin/build-javascript.mjs`.

### Phase 7 — after the migration

- [ ] lostcoords-ui: decide whether the standalone (no-Rails) mode can go.
- [ ] davafons.com health sync: change the cron from hourly to 4×/day (can happen any time, independent of Kiln).
- [ ] Release Kiln 0.1.

## Decisions log

- **URLs:** directory output (`/now/` → `now/index.html`) is the default; `paths: :file` for lostcoords-ui.
- **davafons.com JavaScript:** importmap + Propshaft. Leaflet, uPlot, h3-js and turf load as ES modules
  from `vendor/javascript`. `bin/build-javascript.mjs` goes away.
- **Content layer:** optional part of Kiln (`require "kiln/content"`). It does not depend on the
  exporter, so a normal server-rendered Rails app can use it too.
- **Integrated mode:** not planned (see the Perron table).
- **Rendering:** Rack call against `Rails.application` (decision 1).
- **Home:** github.com/davafons/kiln for now (can move to the lostcoords org later).
- **Versions:** Ruby >= 4.0, Rails >= 8.1. Other apps upgrade to match. A compatibility layer for older
  Ruby only if a real user needs it.
- **Page declarations:** `config/kiln.rb`.
- **davafons.com health data:** stays committed in git, so any clone builds without the qTower bridge.
  The sync runs 4×/day (JST morning, midday, evening, night) instead of hourly.
- **Build environment:** production. Kiln runs `assets:precompile` in-process and removes
  `public/assets` afterwards. Eager loading surfaces load errors at build time.
- **Output folder:** `dist/` by default (Vite/Astro convention; no clash with Rails folders).
  lostcoords-ui sets `output = "docs"` for GitHub Pages. davafons.com deploys `dist/` to Cloudflare Pages.
- **davafons.com localization:** move to Rails I18n (`config/locales/{en,es,ja}.yml`) as part of the
  migration. Translated strings must come out identical, so the old-vs-new page comparison still works.
- **Repo and gem:** public repo at github.com/davafons/kiln. Publish a `kiln` 0.0.1 placeholder to
  RubyGems to hold the name (ask before `gem push`).

## Open questions

None right now.
