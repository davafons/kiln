# Configuration

Options go in the `Kiln.configure` block of `config/kiln.rb`. Every option has a default. This is this site's configuration:

```ruby
Kiln.configure do |config|
  config.url = "https://kiln.davafons.com"
  config.cname = true
  config.not_found = "/404"
end
```

| Option | Default | Summary |
|---|---|---|
| [`output`](#output) | `"dist"` | Output directory. |
| [`url`](#url) | `nil` | Public base URL. |
| [`paths`](#paths) | `:directory` | How a path maps to a file. |
| [`cname`](#cname) | `nil` | Host for a `CNAME` file. |
| [`not_found`](#not_found) | `nil` | Path rendered to `404.html`. |
| [`files`](#files) | `{}` | Files to copy that are not routes. |
| [`verify_skip`](#verify_skip) | `[]` | Selectors the link check ignores. |

Routes with params go in `Kiln.pages`, covered on [Pages](/pages/). The Markdown layer has its own settings, covered on [Markdown](/content/).

## output

The output directory, relative to `Rails.root` or absolute. A successful build replaces it entirely, and a failed build leaves it as it was.

Kiln refuses a directory that is `Rails.root`, contains it, or is the filesystem root, since the build deletes the directory.

## url

The site's public address, such as `"https://example.com"`.

- Its host is the `Host` header of every request a build sends. Without `url` that header is `localhost`.
- Links to that host count as internal in the link check.
- `sitemap.xml` is written only when `url` is set.
- When the app restricts hosts with `config.hosts`, Kiln adds this host to the list.

## paths

| Value | `/now` is written to | Route helpers |
|---|---|---|
| `:directory` | `now/index.html` | Add a [trailing slash](/pages/#trailing-slashes). |
| `:file` | `now.html` | Unchanged. |

## cname

`config.cname = "example.com"` writes that host to a `CNAME` file. `config.cname = true` takes the host from `url`, and fails the build when `url` is not set. GitHub Pages reads this file for a custom domain.

## not_found

The page at this path is rendered to `404.html`, and left out of the normal page list and the sitemap. It may respond with 200 or 404. Any other status is an error.

## files

Files that are not routes, copied into the output. Each key is a path in the output and each value is a file under `Rails.root`. A missing source is an error:

```ruby
config.files = { "octicons-license.txt" => "vendor/octicons/LICENSE" }
```

## verify_skip

CSS selectors for sample markup that links to pages the site does not have, such as component previews. Links inside matching elements are not checked:

```ruby
config.verify_skip = [ "[data-example-preview]" ]
```
