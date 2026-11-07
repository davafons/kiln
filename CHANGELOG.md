# Changelog

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
