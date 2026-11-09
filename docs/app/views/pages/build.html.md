# Build

The reference for `kiln:build` and `kiln:serve`: what a build does, what it writes, and what each error means.

## Commands

| Command | What it does |
|---|---|
| `RAILS_ENV=production bin/rails kiln:build` | Writes the site, and exits with status 1 on any error. `VERBOSE=1` shows the request log. |
| `bin/rails kiln:serve` | Serves the output. Reads `PORT` (default 4000) and `BIND` (default `localhost`). |

`kiln:serve` tries the exact file, then `x.html`, then `x/index.html`. It applies the exact rules in `_redirects` and answers unknown paths with `404.html`. Unlike a static host, it answers `/about` directly instead of redirecting to `/about/`.

## Steps

A build runs in this order:

1. Stops if the output directory is unsafe, or if [development middleware](/views/#development-middleware) is active.
2. Compiles [assets](/views/#assets) when needed.
3. Finds the pages from the routes and [`Kiln.pages`](/pages/).
4. Renders each page through `Rack::MockRequest`, strips CSRF tokens from the HTML, and writes it to a temporary directory next to the output.
5. Renders the `not_found` page.
6. Exports the assets the output references: from HTML `href`, `src` and `srcset`, from the importmap, and from CSS `url()` and `@import`.
7. Copies the `files` option's files, then `public/` without `public/assets`.
8. Writes `_redirects`, `sitemap.xml` and `CNAME` when they apply.
9. Checks every internal link, anchor and importmap module.
10. If there are no errors, replaces the output with the temporary directory and writes `tmp/kiln-manifest.json`.

Pages render one at a time. A build needs no `secret_key_base`, since it ships nothing signed: an app without `SECRET_KEY_BASE`, `RAILS_MASTER_KEY` or a key file boots with Rails' dummy secret.

## Output files

| File | Comes from |
|---|---|
| `index.html`, `about/index.html`, `feed.rss` | A GET route. See [Pages](/pages/). |
| `assets/*` | Assets the output references. |
| `404.html` | The [`not_found`](/configuration/#not_found) option. Replaces a `public/404.html` without a warning. |
| `_redirects` | Routes that redirect, after the rules of `public/_redirects`. |
| `sitemap.xml` | Every HTML page, when `url` is set. Pages marked `noindex` by a robots meta tag or an `X-Robots-Tag` header are left out. |
| `CNAME` | The [`cname`](/configuration/#cname) option. Replaces a `public/CNAME` without a warning. |
| Anything else | `public/`, or the [`files`](/configuration/#files) option. |

When a rendered page and a file in `public/` have the same path, the page is kept and the build prints a warning:

```text
warning /robots.txt: public/robots.txt not copied, a rendered file already exists
```

## Errors

Page-level errors do not stop the build. It carries on, prints them all grouped by kind, exits with status 1 and leaves the output unchanged.

| Group | Example | What to do |
|---|---|---|
| Uncovered route | ``GET /tags/:tag(.:format) (:tag) needs params. Add `params :tag, ...` `` | Add the [param source or skip](/pages/#skips) the message gives. |
| Other | `config/kiln.rb declares :serch, but there is no GET route with that name` | Fix the name in `config/kiln.rb`. |
| Other | `Param source for :post returned {title: "x"}, missing :slug` | Return every required param from the source. |
| Render | `/boom: RuntimeError: no such post (app/controllers/pages_controller.rb:5:in ...)` | Fix the code at that line. The location is the first line in your app. |
| Render | `/gone: responded with 404` | Fix the page, skip the route, or remove it from the param source. |
| Editor markup | `data-herb-*, data-tensaku-* or data-md-source attributes reached /about` | Turn [editor markup](/views/#editor-markup) off outside development. |
| Asset | `/assets/x.png: ActionController::RoutingError: No route matches [GET] "/assets/x.png"` | Use an asset helper, or add the file. Usually listed with a broken link too. |
| Broken link | `/: /contact/` | The page `/` links to `/contact/`, which is not in the output. Fix the link or add the route. |
| Missing anchor | `/: /about/#team` | The page `/` links to an `id` that `/about/` does not have. |
| Importmap | A pinned URL | A module in the importmap is missing from the output. |
| Write | `config.cname = true needs config.url` | Set `url`. A missing `files` source is reported here too. |

A broken link can come from sample markup. To ignore it, use [`verify_skip`](/configuration/#verify_skip).

These problems stop the build at once, with an exception and no report. The output is left unchanged:

| Message | What to do |
|---|---|
| `Refusing to use ... as the output directory` | Point [`output`](/configuration/#output) at a directory that does not contain the app. |
| `... would add development markup to every page` | Load the gem [only under the server](/views/#development-middleware), or build in production. |
| `app/assets/builds did not exist when the app booted` | Track `app/assets/builds/.keep`. |
| `assets:precompile failed` | Fix the asset error the message includes. |

## Changes since the last build

The comparison on the last lines of a successful build reads `tmp/kiln-manifest.json`, which lists each page's digest. It is outside the output, so it is never published. It is only written after a successful build of the configured output, so test builds and failed builds do not change it.
