<p align="center">
  <img src="assets/brand/logo.png" alt="Kiln mascot, a small brick kiln" width="150">
</p>

<h1 align="center">Kiln</h1>

<p align="center">
  <a href="https://rubygems.org/gems/kiln"><img src="https://img.shields.io/gem/v/kiln?color=b45d3c" alt="Gem version"></a>
  <img src="https://img.shields.io/badge/ruby-4.0%2B-cc342d?logo=ruby&amp;logoColor=white" alt="Ruby 4.0+">
  <img src="https://img.shields.io/badge/rails-8.1%2B-d30001?logo=rubyonrails&amp;logoColor=white" alt="Rails 8.1+">
  <a href="https://github.com/davafons/kiln/actions/workflows/ci.yml"><img src="https://github.com/davafons/kiln/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center">
  Build a Rails app into a static site.
</p>

<p align="center">
  <a href="https://kiln.davafons.com">Documentation</a> ·
  <a href="https://kiln.davafons.com/installation/">Installation</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

Kiln sends a GET request through Rack for every route of a Rails app and writes each response to a file. Any static host can serve the result. You write the site with routes, controllers, views, the asset pipeline, Turbo and Stimulus, and work on it with `bin/rails server`.

Kiln needs Ruby 4.0 or later and Rails 8.1 or later. It is at an early version, and the [changelog](CHANGELOG.md) lists breaking changes.

## Build a site

```ruby
# Gemfile
gem "kiln"
```

Routes without params need no declaration. Routes with params need a param source or a skip:

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
bin/rails kiln:serve                       # serve dist/ at http://localhost:4000
```

A build reports every render error, missing asset, broken link and route without params at once, exits with status 1 and leaves the previous output in place. See [Build](https://kiln.davafons.com/build/#errors) for each message.

## Test it

```ruby
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test("the site builds repeatably") { kiln_build(repeatable: true) { assert it.join("index.html").file? } }
  test("the home page") { assert_page "/", selector: "h1", text: "Welcome" }
  test("the sitemap") { assert kiln_site.join("sitemap.xml").file? }
end
```

## Documentation

Start with the [introduction](https://kiln.davafons.com).

- [Install Kiln](https://kiln.davafons.com/installation/) and declare [pages](https://kiln.davafons.com/pages/).
- Read about [views and assets](https://kiln.davafons.com/views/) during a build, and the [Markdown](https://kiln.davafons.com/content/) layer.
- [Test](https://kiln.davafons.com/testing/) and [deploy](https://kiln.davafons.com/deploying/) the site.
- Look up [configuration](https://kiln.davafons.com/configuration/), the [build](https://kiln.davafons.com/build/) and the [known limits](https://kiln.davafons.com/limits/).

## Develop Kiln

```sh
bundle install
bin/test
bin/lint          # RuboCop and bin/house-rules
```

`test/dummy` is the Rails app the tests build. `docs/` is the documentation site, a Rails app that uses this repository's Kiln. Run `bin/rails server` there to work on it, and `RAILS_ENV=production bin/rails kiln:build` and `bin/rails test` to check it; CI runs both. [AGENTS.md](AGENTS.md) holds the rules a script cannot check.

Releases publish from a `vX.Y.Z` tag that matches `Kiln::VERSION`. CI runs first, then the release workflow publishes to RubyGems through trusted publishing.

## License

Copyright © 2026 David Afonso. Kiln is licensed under the [MIT License](LICENSE).
