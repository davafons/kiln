<h1 align="center">Kiln</h1>

<p align="center">
  <a href="https://rubygems.org/gems/kiln"><img src="https://img.shields.io/gem/v/kiln?color=b45d3c" alt="Gem version"></a>
  <img src="https://img.shields.io/badge/ruby-4.0%2B-cc342d?logo=ruby&amp;logoColor=white" alt="Ruby 4.0+">
  <img src="https://img.shields.io/badge/rails-8.1%2B-d30001?logo=rubyonrails&amp;logoColor=white" alt="Rails 8.1+">
  <a href="https://github.com/davafons/kiln/actions/workflows/ci.yml"><img src="https://github.com/davafons/kiln/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center">
  Fire a Rails app into a static site.
</p>

<p align="center">
  <a href="https://kiln.davafons.com">Docs</a> ·
  <a href="https://kiln.davafons.com/installation">Installation</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

Kiln renders every GET route of a Rails app through Rack and writes plain files that any static host can serve. You build pages with normal Rails: routes, controllers, views, helpers, Turbo and Stimulus. Development stays `bin/rails server`.

Routes are the page list. A route that needs params and has no param source fails the build, and every render error, missing asset and broken link is reported at once. Kiln knows nothing about your data: models and repositories stay ordinary app code.

Requires Ruby 4.0+ and Rails 8.1+.

## Quick start

```ruby
# Gemfile
gem "kiln"
```

```ruby
# config/kiln.rb
Kiln.configure do |config|
  config.url = "https://example.com"
  config.not_found = "/404"
end

Kiln.pages do
  params :post, -> { Post.published.map { { slug: it.slug } } }
  skip :search, reason: "dynamic"
end
```

```sh
RAILS_ENV=production bin/rails kiln:build  # write the site to dist/
bin/rails kiln:serve                       # look at it as a static host serves it
```

The [documentation](https://kiln.davafons.com) covers declaring pages, configuration, writing views for a build, the Markdown content layer, testing, deploying and the known limits.

## Develop Kiln

```sh
bundle install
bin/test
bin/lint          # RuboCop and bin/house-rules
```

`test/dummy` is the Rails app the tests build. `docs/` is the documentation site, a Rails app that uses this repository's Kiln. Run `bin/rails server` there to work on it, and `RAILS_ENV=production bin/rails kiln:build` and `bin/rails test` to check it; CI runs both. `bin/house-rules` rejects em dashes, AI attribution, leftover tool-call markup, filler phrases and dead links in Markdown. [AGENTS.md](AGENTS.md) holds the rules a script cannot check.

Releases publish from a `vX.Y.Z` tag that matches `Kiln::VERSION`. CI runs first, then the release workflow publishes to RubyGems through trusted publishing.

## License

Copyright © 2026 David Afonso. Kiln is licensed under the [MIT License](LICENSE).
