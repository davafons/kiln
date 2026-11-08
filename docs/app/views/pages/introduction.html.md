# Introduction

Kiln is a Ruby gem that renders every GET route of a Rails app through Rack and writes plain files that any static host can serve. You build pages with normal Rails: routes, controllers, views, helpers, Turbo and Stimulus. Development stays `bin/rails server`, and a build is one command:

```sh
RAILS_ENV=production bin/rails kiln:build
```

The site lands in `dist/`. This documentation is a Rails app built that way.

## Why a Rails app

A static site generator brings its own templates, its own data layer and its own dev server. Kiln keeps the app you would write anyway. Layouts, partials, helpers, view components, i18n and the asset pipeline work as they do on a server, because a build sends each request through the same Rack stack a browser request would go through.

The same app can also run as a normal Rails server. Kiln adds a rake task and a config file, and nothing in the app has to know about it.

## Routes are the page list

Kiln reads the routes, not a list of files. A GET route without required params becomes a page on its own. A route with params, such as `get "blog/:slug"`, needs a param source in `config/kiln.rb` that lists the values to build. A route that needs params and has neither a source nor a skip fails the build, and the error names the line to add. [Declaring pages](/pages/) covers the details.

## The build fails loudly

A build collects every problem and reports them together: render errors, pages that respond with an error status, assets that don't resolve, broken internal links and anchors, importmap modules that are missing, and routes without a param source. Then the task exits non-zero. Nothing is published half-built by accident.

## Kiln knows nothing about your data

Kiln has no models, data sources or collections in its core. Your models, repositories and Markdown files stay ordinary app code, and param sources are plain lambdas that call them. The optional [content layer](/content/) renders Markdown views and reads Markdown collections, and it works the same in an app that is never built statically.

## What a build does

1. Precompiles assets in-process into a temporary directory.
2. Walks the GET routes, expands each one with its param source, and renders every page through `Rack::MockRequest`.
3. Strips CSRF tokens and meta tags. The rest of the HTML stays byte for byte as the app rendered it.
4. Exports the assets the pages reference, copies `public/`, and writes `_redirects`, `sitemap.xml`, `404.html` and `CNAME` when they apply.
5. Checks every internal link, anchor and importmap module in the output.

[Configuration](/configuration/) lists what each step writes and the options that change it.

## Requirements

Kiln needs Ruby 4.0 or later and Rails 8.1 or later. The content layer also needs the commonmarker and rouge gems.
