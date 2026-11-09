# Markdown

Kiln's Markdown layer renders Markdown views and reads directories of Markdown files with YAML frontmatter. It is optional and separate from the build, so it also works in an app that runs on a server.

## Setup

```ruby
# Gemfile
gem "commonmarker"
gem "rouge"
```

```ruby
# config/application.rb, after Bundler.require
require "kiln/content"
```

An app that does not require `kiln/content` never loads commonmarker or Rouge.

## Markdown views

A view with the `.md` handler renders through the layout like any other view. `.md.erb` runs ERB first, then Markdown:

```text
app/views/pages/about.html.md
app/views/pages/changelog.html.md.erb
```

Markdown is GitHub Flavored, with tables, strikethrough and autolinks. Raw HTML passes through. Headings get an `id` and no anchor link, so the app decides how to link them.

## Code highlighting

Rouge highlights code blocks with CSS classes and no inline styles, so add a Rouge theme to your stylesheet. `rougify style github` prints one. Each block keeps its fence's language in `data-language`, also when Rouge has no lexer for it:

```html
<pre class="highlight plaintext" data-language="diagram"><code>…</code></pre>
```

## Rendering in Ruby

```ruby
Kiln::Content::Markdown.render("A *short* text.")
# => "<p>A <em>short</em> text.</p>\n"

Kiln::Content::Markdown.render_inline("A *short* text.")
# => "A <em>short</em> text."
```

`render_inline` drops the `<p>` around a single paragraph, for titles and captions. Other text renders as with `render`.

## Collections

A collection is a directory under `content/`. Set `Kiln::Content.root` to use another directory. Each `*.md` file in it is an entry, and `.md.erb` is not read:

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

post = posts.find("hello")
post.slug                     # "hello"
post.title                    # frontmatter title, or the slug in title case
post.published_at             # from the frontmatter or the filename, or nil
post.body                     # the Markdown without the frontmatter
post.html                     # the rendered Markdown
post[:tags]                   # any frontmatter key
post.tags                     # the same key by name
```

A collection is `Enumerable` over its visible entries. An entry's `to_param` is its slug, so it can go straight into a route helper. Frontmatter may contain dates, times and symbols.

To build a page for each entry, use a collection in a param source:

```ruby
# config/kiln.rb
Kiln.pages do
  params :post, -> { Kiln::Content.collection("blog").map { { slug: it.slug } } }
end
```

During a build each collection is read once. On a development server it is read again when a file in its directory is added, removed or changed.

## Filenames

The filename sets the slug, and can set the date and the locale:

| File | `slug` | `published_at` | `locale` |
|---|---|---|---|
| `hello.md` | `hello` | none | none |
| `2024-05-01-hello.md` | `hello` | 2024-05-01 | none |
| `2024-05-hello.md` | `hello` | 2024-05-01 | none |
| `2026-08.md` | `2026-08` | 2026-08-01 | none |
| `hello.es.md` | `hello` | none | `es` |
| `2026-08.pt-BR.md` | `2026-08` | 2026-08-01 | `pt-BR` |

A `published_at` in the frontmatter wins over the filename. Entries without a date sort last.

## Translations

`SLUG.LOCALE.md` is a translation of the entry with that slug. A locale is two lowercase letters, optionally followed by a dash and two uppercase letters. Translations stay out of `all`, `find` and `each`:

```ruby
post.locale            # nil for SLUG.md, "es" for SLUG.es.md
post.translation(:es)  # the visible SLUG.es.md entry, or nil
```

A translation whose entry does not exist fails when the collection loads.

## Drafts and scheduled entries

Entries with `draft: true` or a future `published_at` are hidden. In development they are visible on `bin/rails server`, so you can preview them, and hidden during a build. Set `Kiln::Content.show_drafts` to `true` or `false` to override that.

## Single files

`Kiln::Content.file(path)` reads one Markdown file from anywhere, such as the repository's README, as an entry:

```ruby
guide = Kiln::Content.file(Rails.root.join("../CONTRIBUTING.md"))
guide.title
guide.html
guide[:description]
```

Its slug follows the same [filename rules](#filenames). A name that does not end in `.md` raises `ArgumentError`. The file is read again when it changes, and once per build.

## Source positions

With source positions on, each block rendered from a `.md` view or entry carries a `data-md-source` attribute, for in-page editors such as [Tensaku](https://tensaku.lostcoords.com):

```ruby
# config/initializers/kiln.rb
Kiln::Content.source_positions = Rails.env.development?
```

```html
<p data-md-source="app/views/pages/about.html.md:3:1-3:42">…</p>
```

- The format is `path:startLine:startCol-endLine:endCol`. The path is relative to `Rails.root`. Lines start at 1, columns are commonmarker byte columns, and the end is inclusive.
- Only these elements carry it: `p`, `h1` to `h6`, `ul`, `ol`, `li`, `blockquote`, `pre`, `table` and `hr`.
- `.md.erb` views get none, because ERB shifts the line numbers.
- It is off until the app turns it on, and always off during a build.
