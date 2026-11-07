# Markdown content

Kiln's content layer renders Markdown views and reads Markdown collections with YAML frontmatter. It is optional, separate from the build, and works the same in a server-rendered app.

## Setup

The content layer needs commonmarker and Rouge, and an explicit require:

```ruby
# Gemfile
gem "commonmarker"
gem "rouge"
```

```ruby
# config/application.rb, after Bundler.require
require "kiln/content"
```

It stays out of Kiln's autoloader, so an app that never requires it never loads commonmarker or Rouge.

## Markdown views

A view with the `.md` handler renders through the layout like any other view:

```text
app/views/pages/about.html.md
app/views/pages/changelog.html.md.erb
```

`.md.erb` runs ERB first, then Markdown. Every page on this site is a `.html.md` view, and the installation page is `.html.md.erb` so it can print `Kiln::VERSION`.

commonmarker renders GitHub Flavored Markdown with tables, strikethrough, autolinks and heading ids. Raw HTML passes through. Headings carry only the `id`, with no anchor link, so the app decides how to link them. This site passes the rendered HTML to `lc_prose(anchors: true)` and `lc_toc(headings:)` from lostcoords-ui for the heading links and the "On this page" list.

Code blocks are highlighted by Rouge with CSS classes and no inline styles, so add a Rouge theme to your stylesheet. `rougify style github` prints one.

## Rendering Markdown in Ruby

```ruby
Kiln::Content::Markdown.render("A *short* text.")
# => "<p>A <em>short</em> text.</p>\n"

Kiln::Content::Markdown.render_inline("A *short* text.")
# => "A <em>short</em> text."
```

`render_inline` drops the `<p>` around text that is a single paragraph, for titles and captions. Other text renders as with `render`.

## Collections

A collection is a directory of Markdown files with YAML frontmatter under `content/`, such as `content/blog/2024-05-01-hello.md`:

```markdown
---
title: Hello
tags: [rails]
---
The first post.
```

```ruby
posts = Kiln::Content.collection("blog")
posts.all                     # visible entries, newest first
posts.find("hello")           # raises Kiln::Content::NotFound, which Rails maps to a 404
posts.find_by(slug: "hello")  # or nil

post.slug, post.title, post.published_at, post.html
post[:tags], post.tags        # frontmatter keys, by [] or by name
```

A collection is `Enumerable` over its visible entries. `title` comes from the frontmatter, or from the slug when there is none. `body` is the Markdown without the frontmatter, and `to_param` is the slug, so an entry can go straight into a route helper. Frontmatter may contain dates, times and symbols. `Kiln::Content.root` sets the directory, and defaults to `Rails.root.join("content")`.

A collection pairs with a param source:

```ruby
# config/kiln.rb
Kiln.pages do
  params :post, -> { Kiln::Content.collection("blog").map { { slug: it.slug } } }
end
```

During a build, each collection is read once and kept in `Kiln.build_cache`. On a development server, it is read again when a file in its directory is added, removed or changed. Collections read `*.md` files only: `.md.erb` works for views, not collection entries.

## Filenames and dates

A filename that starts with a `YYYY-MM-DD` or `YYYY-MM` date sets `published_at`, and the rest of the name is the slug. A month-only date means the 1st of that month. A filename that is only a date, such as `2026-08.md`, keeps the date as its slug. A `published_at` in the frontmatter wins over the filename.

## Translations

`SLUG.LOCALE.md` is a translation of the entry with that slug, such as `2026-08.es.md` for `2026-08.md`. A locale is two lowercase letters, optionally followed by a dash and two uppercase letters: `es`, `pt-BR`. Translations stay out of `all`, `find` and `each`:

```ruby
post.locale            # nil for SLUG.md, "es" for SLUG.es.md
post.translation(:es)  # the visible SLUG.es.md entry, or nil
```

A translation whose entry does not exist fails when the collection loads.

## Drafts and scheduled entries

Entries with `draft: true` or a future `published_at` are hidden. They show in development when Kiln is not building, so a draft can be previewed on `bin/rails server` and never reaches a build. Set `Kiln::Content.show_drafts` to `true` or `false` to override that.

## Tensaku source positions

With `Kiln::Content.source_positions` on, each rendered block of a `.md` view or collection entry carries a `data-tensaku-md` attribute for the [Tensaku](https://tensaku.lostcoords.com) editor:

```html
<p data-tensaku-md="app/views/pages/about.html.md:3:1-3:42">…</p>
```

The value is the path relative to `Rails.root`, then the start and end line and column. The format is a draft. `.md.erb` views get none, because ERB shifts the line numbers. The setting defaults to on in development when Tensaku is loaded, and it is always off while Kiln is building, so the attributes never reach the output.
