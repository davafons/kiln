# Kiln

Kiln fires a Rails app into a static site: every GET route renders through Rack into plain files.
Use jj for version control; preserve unrelated work and never use mutating Git commands.

- Kiln knows nothing about the app's data. No models, data sources or collections in the core.
- Fail loudly: page-level problems go in the build report, every failure at once, and the task exits non-zero.
- Rendering goes through `Rack::MockRequest` against `Rails.application`, never controller dispatch or `Integration::Session`.
- Output must stay byte-stable. Processors edit strings; never re-serialize a document through Nokogiri.
- `kiln/content` and `kiln/test_helper` stay outside the Zeitwerk loader: production eager loading must not require commonmarker or Minitest.
- `test/dummy` is the integration fixture. Its routes feed the coverage check, so every new route needs a param source, a skip, or no params.
- Run `bin/lint` and `bin/test` for code changes. `bin/house-rules` enforces the writing rules a grep can decide.
- Releases publish from a `vX.Y.Z` tag through trusted publishing. Never run `gem push`, and never tag without the user's approval.
- No AI attribution in commits, pull requests or files.

Design decisions:

- Two tasks: `kiln:build` and `kiln:serve`. Development is `bin/rails server` with the app's own reloading; Kiln adds no dev server.
- Builds run in production by default, with `assets:precompile` in-process and `public/assets` removed afterwards.
- Ruby >= 4.0 and Rails >= 8.1. Breaking changes are fine; say so in the CHANGELOG.
- No integrated mode (Kiln never serves the app in production) and no parallel rendering yet.
- Tensaku depends on `Kiln::Content.root` and on the `data-tensaku-md` format: `path:startLine:startCol-endLine:endCol`, 1-based lines, commonmarker byte columns with an inclusive end, path relative to `Rails.root`, on block elements only, headings without an anchor link. Tell the Tensaku session before changing either.

Writing (README, CHANGELOG, comments):

- Plain, factual sentences. Say what a thing does; no promotional adjectives or filler.
- No em dashes. Use a colon, a full stop, or commas.
- State facts forward, without an account of earlier wording. The history lives in jj.
- Describe verified behavior only, and name what is unsupported or unverified.
