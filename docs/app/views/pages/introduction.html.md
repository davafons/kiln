# Introduction

Kiln builds a Rails app into a static site. It sends a GET request through Rack for every route and writes each response to a file. Any static host can serve the result.

You write the site as an ordinary Rails app, with controllers, views, layouts, helpers, the asset pipeline, Turbo and Stimulus. You work on it with `bin/rails server`. Kiln adds one config file and two rake tasks, and the deployed site has no Rails server behind it.

## An example

A small blog has these routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"
  get "about", to: "pages#about"
  get "blog/:slug", to: "posts#show", as: :post
  get "feed", to: "posts#feed", defaults: { format: :rss }
  get "404", to: "pages#not_found"
end
```

Kiln builds a route without params as it is. `blog/:slug` has a param, so `config/kiln.rb` lists the values to build:

```ruby
# config/kiln.rb
Kiln.configure do |config|
  config.url = "https://example.com"
  config.not_found = "/404"
end

Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
end
```

`Post` is the app's own code. Kiln has no data layer: the lambda runs at build time and can read a database, files or an API.

A build writes the site to `dist/`:

```sh
RAILS_ENV=production bin/rails kiln:build
```

```text
dist/
├── index.html
├── about/index.html
├── blog/hello/index.html
├── blog/second-post/index.html
├── feed.rss
├── 404.html
├── sitemap.xml
└── assets/application-7cff19ac.css
```

## When a build fails

A build does not stop at the first problem. It reports all of them, exits with status 1 and leaves the previous `dist/` in place:

```text
Kiln build failed with 3 errors:

  Uncovered route (1)
    GET /tags/:tag(.:format) (:tag) needs params. Add `params :tag, -> { [ { tag: ... } ] }` or `skip :tag, reason: "..."` to config/kiln.rb.

  Render (1)
    /boom: RuntimeError: no such post (app/controllers/pages_controller.rb:5:in 'PagesController#boom')

  Broken link (1)
    /: /contact/
Output left unchanged: /path/to/app/dist (production, 0.1s)
```

The [build reference](/build/#errors) lists every kind of error.

## What does not work

The output is plain files, so nothing runs per request. Forms, sessions and server-side search need an external service, or their routes need to be skipped. [Known limits](/limits/) has the full list.

## Requirements

Ruby 4.0 or later and Rails 8.1 or later. The optional [Markdown layer](/content/) also needs the commonmarker and rouge gems.

Kiln is at an early version and breaking changes are possible in any release. The [changelog](https://github.com/davafons/kiln/blob/main/CHANGELOG.md) lists them.

## Where to go next

- [Install Kiln](/installation/) and run a first build.
- Declare [pages](/pages/) for routes with params, redirects and feeds.
- Read what is different about [views and assets](/views/) during a build.
- Render [Markdown](/content/) views and collections.
- [Test](/testing/) the site and [deploy](/deploying/) it.

This site is a Rails app built with Kiln. Its source is in the [docs folder](https://github.com/davafons/kiln/tree/main/docs) of the repository.
