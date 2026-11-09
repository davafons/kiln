# Pages

Kiln builds the app's GET routes. A route without required params needs no declaration. A route with required params needs either a param source or a skip in the `Kiln.pages` block of `config/kiln.rb`.

## Routes without params

These routes are built with nothing in `config/kiln.rb`:

```ruby
# config/routes.rb
root "pages#home"
get "about", to: "pages#about"
get "blog", to: "posts#index"
```

`/` is written to `index.html`, `/about` to `about/index.html` and `/blog` to `blog/index.html`. Optional segments such as `(:locale)` do not count as required.

## Param sources

A param source is keyed by the route name. It is a lambda that returns one hash for each page:

```ruby
# config/routes.rb
get "blog/:slug", to: "posts#show", as: :post

# config/kiln.rb
Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
end
```

The rules:

- The lambda runs during the build, after the app has booted.
- Each hash must have every required param of the route.
- Values go through `to_param`, and `nil` values are dropped.
- Two hashes that produce the same path build one page.
- A source that raises, returns something other than a list, or misses a param is reported as an error. The build carries on with the other routes.

## Value lists

`params` also takes a list of values for each key, and builds every combination:

```ruby
Kiln.pages do
  params :page, locale: [ nil, "es", "ja" ]                         # /page, /es/page, /ja/page
  params :archive, year: -> { Post.years }, locale: [ nil, "es" ]   # each year, in each locale
end
```

`nil` leaves the key out, which fills an optional segment such as `(:locale)` with nothing. A list may be a lambda, called during the build.

A source and value lists combine every hash from the source with every value:

```ruby
params :post, -> { Post.all.map { { slug: it.slug } } }, locale: [ nil, "es" ]  # /blog/x and /es/blog/x
```

This site has one route, `get "(:slug)"`, for all of its pages. Its value list is `slug: -> { Docs::PAGES.map(&:slug) }`, and the introduction's `nil` slug is the home page.

## Pagination

A paginated route is a value list of page numbers:

```ruby
# config/routes.rb
get "blog", to: "posts#index"
get "blog/page/:page", to: "posts#index", as: :blog_page

# config/kiln.rb
Kiln.pages do
  params :blog_page, page: -> { 2..Post.count.fdiv(10).ceil }
end
```

Page 1 is at `/blog`, so the list starts at 2. With 10 posts or fewer the list is empty and only `/blog` is built.

## Skips

`skip` leaves a route out of the build. The reason is optional:

```ruby
Kiln.pages do
  skip :search, reason: "dynamic"
end
```

A route that needs params and has neither a source nor a skip fails the build, and the error gives the line to add. An unnamed route can't be declared, so its error asks you to add `as:` first. A name in `config/kiln.rb` that matches no GET route is also an error, which catches typos and renamed routes.

These routes are skipped without a declaration, unless `config/kiln.rb` declares them:

- Rails internal routes, and any route under `/rails/`.
- The Rails health check, `rails/health#show`.
- The native navigation routes of turbo-rails.
- Mounted engines.

Mounted Rack apps that are not engines count as ordinary routes.

## Redirects

A route that responds with a redirect becomes a rule in `_redirects`:

```ruby
# config/routes.rb
get "old-about", to: redirect("/about")
```

```text
# dist/_redirects
/old-about /about 301
```

A target on the site's own host is written as a path. Rules from a `public/_redirects` file come first, so hand-written rules win. Links to a redirect source count as valid in the link check.

Cloudflare Pages and Netlify read `_redirects`. GitHub Pages ignores it, so these routes do not redirect there.

## Feeds, JSON and text

Feeds, `robots.txt`, `llms.txt` and JSON files are ordinary routes with views. When the path has no extension, the response's content type picks one:

```ruby
# config/routes.rb
get "api", to: "api#index", defaults: { format: :json }   # api.json
get "feed", to: "posts#feed", defaults: { format: :rss }  # feed.rss
get "llms", to: "pages#llms", defaults: { format: :text } # llms.txt
get "robots.txt", to: "pages#robots"                      # robots.txt, as written
```

For a file that does not come from a route, such as a license text, use the [`files` option](/configuration/#files).

## Trailing slashes

With the default `paths: :directory`, `/about` is written to `about/index.html`, which static hosts serve at `/about/`. So Kiln sets `trailing_slash: true` in the app's `default_url_options`, and `about_path` returns `/about/`, on a development server too.

Paths with a dot, such as `/feed.xml`, keep no slash. An app that sets `trailing_slash` in `Rails.application.routes.default_url_options` keeps its own value.

With `paths: :file`, `/about` is written to `about.html` and route helpers are unchanged.
