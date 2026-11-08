# Changelog

## Unreleased

- The sitemap lists a page written as `now/index.html` at `/now/`, the URL a static host serves it
  at, instead of `/now`. Pages written as `now.html` keep `/now`.

- `Kiln::Content.file(path)` reads one Markdown file outside the content directory, such as a
  README or CONTRIBUTING.md, as an entry with frontmatter, `html` and source positions. It is read
  again when the file changes, and once per build.
- Highlighted code blocks carry the fence's language as `data-language`, also when Rouge has no
  lexer for it, so an app can style or wrap a block by language.

- `kiln:build` boots an app without its own secret with `SECRET_KEY_BASE_DUMMY`, so gems that read
  `secret_key_base` while booting (turbo-rails) no longer fail the build.

## 0.1.2 (2026-11-07)

Breaking:

- `Kiln.build_cache.fetch` caches only while `Kiln.building?`. Outside a build it runs the block
  every time. `read`, `write` and `delete` are removed.
- `assert_repeatable_build` is removed. Use `kiln_build(repeatable: true) { |output| ... }`.
- In collections, `SLUG.LOCALE.md` (such as `2026-08.es.md`) is a translation of `SLUG.md` instead
  of its own entry. Translations stay out of `all`, `find` and `each`, and a translation without
  its entry fails when the collection loads.
- A collection filename that is only a date, such as `2026-08-01.md`, now sets `published_at`.
- Removed options: `config.verify` (every build verifies), `config.absolute_urls`,
  `config.external_links`, `config.processors`, `config.before_build`, `config.after_build`,
  `config.strip_source_maps` (source maps are always stripped), `config.sitemap` (written whenever
  `url` is set), `config.host=` (the host comes from `url`, else `localhost`), `config.assets`
  (only referenced assets are exported), `config.redirects` (always `_redirects`; the
  `:meta_refresh`, `:both` and `false` modes are gone) and `config.copy_public` (`public/` is always
  copied).
- Removed `Kiln::Processors.apply`, `Kiln::Processors::Context`, `Kiln::Build::Context`, and the
  `AbsoluteUrls` and `ExternalLinks` processors.
- The content layer drops preview tokens: `Collection#find` takes only a slug, and
  `Entry#preview_token` and `Kiln::Content.preview_secret` are removed. Drafts and scheduled
  entries still show in development when Kiln is not building.

Added:

- `params :page, locale: [ nil, "es", "ja" ]` builds every combination of value lists. `nil`
  leaves the key out, for optional segments. A list may be a lambda, called at build time.
- `kiln_build(repeatable: true)` builds twice, fails with the diff when the outputs differ, and
  yields the first output.
- `entry.translation(:es)` and `entry.locale` in the content layer.
- Collection filenames may start with a `YYYY-MM` date, which means the 1st of that month.
- `Kiln::Content::Markdown.render_inline(text)` renders a single paragraph without its `<p>`.
- `config.cname = true` writes `CNAME` with the host from `config.url`.

Fixed:

- A production build precompiles assets into a temporary directory instead of `public/assets`, so
  a development server that boots during the build no longer loads the production manifest.
  Compiled assets are exported from that directory, and the build no longer needs
  `config.public_file_server.enabled`.
- When `app/assets/builds` is created after boot (a fresh checkout without
  `app/assets/builds/.keep`), the build stops with one error that says to track the `.keep` file,
  instead of one missing-asset error per page.

## 0.1.1 (2026-11-07)

- Kiln has two tasks, `kiln:build` and `kiln:serve`. `kiln:verify`, `kiln:routes` and `kiln:check` are removed: every build verifies and reports uncovered routes, and committed output can be checked with `git status --porcelain` after a build.
- `config.verify_skip`: CSS selectors for sample markup (component demos, previews) whose links the
  verifier ignores.
- `kiln:serve` takes `BIND` (default localhost), for process managers that expect 127.0.0.1.
- `config.files` copies files that aren't routes (licenses, verification files) into the output.
- Development builds run the bundle builds hooked into `assets:precompile` (`tailwindcss:build`,
  `javascript:build`, `css:build`) instead of shipping stale bundles.
- The build fails when development middleware that injects markup (Hotwire Spark, web-console,
  rack-mini-profiler) is active.
- The manifest moved from the output to `tmp/kiln-manifest.json`, so it is no longer published.
- LICENSE names the copyright holder.
- A production build of an app without `secret_key_base` uses a throwaway secret instead of failing.
- The build fails when `data-herb-*` or `data-tensaku-*` editor attributes reach the output.
- The content layer renders Markdown with commonmarker instead of Redcarpet: replace `gem "redcarpet"`
  with `gem "commonmarker"`. The HTML changes, for example lists directly under a paragraph become lists and `^` is no longer superscript. Headings keep a plain `id`.
- `Kiln::Content.source_positions` marks rendered Markdown blocks with `data-tensaku-md` source
  positions. On by default only in development with Tensaku loaded, never while building.

## 0.1.0 (2026-11-07)

- First release.
