# Configuration

Options go in the `Kiln.configure` block of `config/kiln.rb`:

```ruby
Kiln.configure do |config|
  config.url = "https://kiln.davafons.com"
  config.cname = true
  config.not_found = "/404"
end
```

That is this site's configuration. Kiln has seven options, and every one has a default.

## Options

| Option | Default | What it does |
|---|---|---|
| `output` | `"dist"` | The output directory, relative to `Rails.root` or absolute. It is wiped at the start of every build. |
| `url` | `nil` | The public base URL. Its host is sent with every request (`localhost` without it), and `sitemap.xml` is written only when it is set. |
| `paths` | `:directory` | `/now` is written to `now/index.html`. `:file` writes `now.html`. |
| `cname` | `nil` | Writes a `CNAME` file with this host. `true` takes the host from `url`. |
| `not_found` | `nil` | The path rendered to `404.html`. It may respond with 200 or 404. |
| `files` | `{}` | Files that are not routes, copied into the output: `{ "octicons-license.txt" => "vendor/octicons/LICENSE" }`. Sources are relative to `Rails.root`. |
| `verify_skip` | `[]` | CSS selectors for sample markup whose links are not checked, such as `"[data-example-preview]"`. |

### output

Kiln refuses an output directory that is `Rails.root`, contains it, or is the filesystem root, since the build deletes the directory first.

### url

The host of `url` is the `Host` header of every request a build sends, and links to that host count as internal for the link checker. When the app restricts hosts with `config.hosts`, Kiln adds this host to the list.

### cname

`config.cname = "example.com"` writes `example.com` to `CNAME`. `config.cname = true` takes the host from `url`, and fails the build when `url` is not set. GitHub Pages reads the file for a custom domain.

### not_found

The page at this path is rendered to `404.html` and left out of the normal page list and the sitemap. It may respond with 200 or 404; any other status is an error. Rails apps ship a `public/404.html`, and the rendered page replaces it without a warning.

### files

Each key is a path in the output and each value a file under `Rails.root`. A missing source is an error.

### verify_skip

Links inside elements that match these selectors, and inside their descendants, are not checked. Use it for component previews or sample markup that links to pages the site does not have.

## What every build does

These steps have no option. Every build:

- Precompiles assets into a temporary directory and exports only the assets the output references: from HTML `href`, `src` and `srcset`, from the importmap, and from CSS `url()` and `@import`.
- Removes `sourceMappingURL` comments from exported JavaScript and CSS.
- Strips CSRF tokens and the `csrf-param` and `csrf-token` meta tags. The rest of the HTML stays byte for byte as the app rendered it.
- Copies `public/`, minus `public/assets`. A rendered file with the same path wins, with a warning.
- Writes `_redirects` when a route redirects.
- Writes `sitemap.xml` with every HTML page when `url` is set, at the URL its file is served at: `now/index.html` is `/now/`. Pages marked `noindex`, with a robots meta tag or an `X-Robots-Tag` header, are left out.
- Checks every internal link, anchor and importmap module in the output.

An app without a `secret_key_base` needs none for a build, since the build ships nothing signed. `kiln:build` boots such an app with Rails' dummy secret (`SECRET_KEY_BASE_DUMMY`), so gems that read the secret while booting, such as turbo-rails, work too. An app with `SECRET_KEY_BASE`, `RAILS_MASTER_KEY` or a key file keeps its own secret.

## Commands

| Command | What it does |
|---|---|
| `RAILS_ENV=production bin/rails kiln:build` | Writes the site and exits non-zero on any error. `VERBOSE=1` shows the request log. |
| `bin/rails kiln:serve` | Serves the output the way a static host does. Reads `PORT` (default 4000) and `BIND` (default `localhost`). |
