# Changelog

## 0.1.4 (2026-11-13)

Breaking:

- A production build always compiles assets into a temporary directory. An existing
  `public/assets/.manifest.json` no longer skips the compile, so a stale `public/assets` can't ship
  old assets.

## 0.1.3 (2026-11-08)

Breaking:

- With `paths: :directory`, route helpers add a trailing slash (`about_path` is `/about/`), the URL a
  static host serves `about/index.html` at. Kiln sets `trailing_slash: true` in the app's
  `default_url_options` unless the app sets it. Paths with a dot keep no slash.
- The sitemap lists a page written as `now/index.html` at `/now/` instead of `/now`. Pages written
  as `now.html` keep `/now`.
- Source positions use `data-md-source` instead of `data-tensaku-md`, and
  `Kiln::Content.source_positions` is off until the app turns it on. Kiln no longer checks whether
  Tensaku is loaded: set `Kiln::Content.source_positions = Rails.env.development?`.
- `paginate` is removed. A value list does the same:
  `params :blog_page, page: -> { 2..Post.count.fdiv(10).ceil }`.
- Highlighted code blocks carry the fence's language as `data-language`, also when Rouge has no
  lexer for it. Code that matches `<pre class="highlight ..."><code>` with a regex should select
  `pre.highlight` instead.

- A build writes into `.OUTPUT.kiln-build` next to the output directory and replaces the output
  only when it succeeds. A failed build leaves the previous output, and `tmp/kiln-manifest.json`,
  as they were, instead of a half-written directory.

Added:

- `Kiln.render(path)` returns another page's body as the build writes it, for pages made from other
  pages such as a search index. During a build each page is rendered once, shared between the build
  and every `Kiln.render` call.
- `params :post, -> { ... }, locale: [ nil, "es" ]` combines a source with value lists.
- `Kiln::Content.file(path)` reads one Markdown file outside the content directory, such as a
  README or CONTRIBUTING.md, as an entry with frontmatter, `html` and source positions. It is read
  again when the file changes, and once per build. A name that does not end in `.md` raises
  `ArgumentError`.
- The last line of `kiln:build` names the Rails environment the build ran in.

Fixed:

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
