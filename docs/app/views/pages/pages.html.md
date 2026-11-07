# Declaring pages

Kiln builds the app's GET routes. This page covers how each kind of route becomes files, and what goes in the `Kiln.pages` block of `config/kiln.rb`.

## Routes without params

A GET route with no required params is built on its own. Nothing goes in `config/kiln.rb`:

```ruby
# config/routes.rb
root "pages#home"
get "about", to: "pages#about"
get "blog", to: "posts#index"
```

With the default `paths: :directory`, `/` is written to `index.html` and `/about` to `about/index.html`. Optional segments that are left out, such as `(:locale)`, don't count as required.

## Param sources

A route with required params needs a param source, keyed by the route name. The source is a lambda that returns a list of hashes, one per page:

```ruby
# config/routes.rb
get "blog/:slug", to: "posts#show", as: :post

# config/kiln.rb
Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
end
```

The lambda runs at build time, after the app has booted. Each hash must have every required param of the route. Values go through `to_param`, and `nil` values are dropped. Two hashes that produce the same path build one page.

A source that raises, returns something that is not a list, or returns a hash without a required key is reported as an error, and the build carries on with the other routes.

## Value lists

Instead of a lambda, `params` takes a list of values for each key and builds every combination:

```ruby
Kiln.pages do
  params :page, locale: [ nil, "es", "ja" ]                         # scope "(:locale)"
  params :archive, year: -> { Post.years }, locale: [ nil, "es" ]   # every combination
end
```

A `nil` value leaves the key out, which fills an optional segment such as `(:locale)` with nothing. So the first line builds `/page`, `/es/page` and `/ja/page`. A list may be a lambda, called at build time. `params` takes a source or value lists, not both.

This site uses a value list: one route, `get ":slug"`, serves every documentation page, and `config/kiln.rb` lists the slugs with `params :page, slug: -> { Docs::PAGES.map(&:slug) }`.

## Pagination

`paginate` declares the pages of a paginated route:

```ruby
# config/routes.rb
get "blog", to: "posts#index"
get "blog/page/:page", to: "posts#index", as: :blog_page

# config/kiln.rb
Kiln.pages do
  paginate :blog_page, per: 10, total: -> { Post.count }, start: 2
end
```

It builds pages from `start` to the last page, which is `total` divided by `per`, rounded up. The start page is always built, so an empty list still gets its first page. `start` defaults to 1; use `start: 2` when page 1 lives at another route, as above. `param` names the route param and defaults to `:page`. `per` must be a positive integer.

## Skips

`skip` leaves a route out of the build. The reason is optional:

```ruby
Kiln.pages do
  skip :search, reason: "dynamic"
end
```

A route that needs params and has neither a param source nor a skip fails the build. The error names the line to add:

```text
GET /blog/:slug(.:format) (:post) needs params. Add `params :post, -> { [ { slug: ... } ] }` or `skip :post, reason: "..."` to config/kiln.rb.
```

A route without a name can't be declared, so the error asks you to add `as:` to it first. A name in `config/kiln.rb` that matches no GET route is also an error, which catches typos and renamed routes.

## Default skips

These routes are skipped without a declaration:

- Rails internal routes, and any route under `/rails/`.
- The Rails health check (`rails/health#show`).
- turbo-rails' native navigation routes.
- Mounted engines.

A declaration in `config/kiln.rb` wins over a default skip.

## Redirects

A route that responds with a redirect becomes a rule in `_redirects`:

```ruby
# config/routes.rb
get "feed", to: redirect("/blog/feed.xml")
```

```text
# dist/_redirects
/feed /blog/feed.xml 301
```

A target on the site's own host is written as a path. Cloudflare Pages and Netlify read `_redirects`. GitHub Pages ignores it, so redirect routes do not redirect there. Rules from a `public/_redirects` file come first, so hand-written rules win. The link checker treats a link to a redirect source as valid.

## Feeds, JSON and text

Feeds, `robots.txt`, `llms.txt` and JSON files are ordinary routes with views. The response's content type picks the file extension when the path has none:

```ruby
# config/routes.rb
get "api", to: "api#index", defaults: { format: :json }   # written as api.json
get "feed", to: "posts#feed", defaults: { format: :rss }  # written as feed.rss
get "robots.txt", to: "pages#robots"                      # the path already has an extension
```

HTML gets `index.html` or `.html` depending on `paths`, and `text/plain` gets `.txt`. This site's [llms.txt](/llms.txt) is the route `get "llms"` with a `.text.erb` view.

Mounted Rack apps that are not engines are built like any other route, so a Rack endpoint mounted at a path without params is rendered and written as well.
