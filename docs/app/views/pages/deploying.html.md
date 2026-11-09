# Deploying

The output is a directory of plain files, so any static host can serve it. Kiln has been used on Cloudflare Pages and GitHub Pages. Other hosts should work, and the notes on Netlify below come from its documented `_redirects` format, not from a test.

## What each host reads

| File | Written when | Read by |
|---|---|---|
| `404.html` | `not_found` is set | Cloudflare Pages, GitHub Pages and Netlify, for unknown paths. |
| `_redirects` | A route redirects, or `public/_redirects` exists | Cloudflare Pages and Netlify. GitHub Pages ignores it. |
| `CNAME` | `cname` is set | GitHub Pages, for a custom domain. |
| `sitemap.xml` | `url` is set | Search engines. |

With the default `paths: :directory`, `/about` is written to `about/index.html`. Cloudflare Pages and GitHub Pages serve that file at `/about/` and redirect `/about` to it. With `paths: :file`, it is written to `about.html` and served at `/about`.

## Cloudflare Pages

Build in CI and upload the output with Wrangler:

```sh
RAILS_ENV=production bin/rails kiln:build
npx wrangler pages deploy dist --project-name=my-site
```

## GitHub Pages

GitHub Pages reads `404.html` and `CNAME`, but ignores `_redirects`. A redirect route still builds, and its old path answers with the 404 page. Keep redirect routes out of a site deployed there, or use another host.

This workflow builds and deploys the site. The repository's Pages setting must use GitHub Actions as its source:

```yaml
# .github/workflows/docs.yml
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "4.0"
          bundler-cache: true
      - run: bin/rails kiln:build
        env:
          RAILS_ENV: production
      - uses: actions/upload-pages-artifact@v5
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-24.04
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
    steps:
      - uses: actions/deploy-pages@v5
```

This site deploys with a [workflow like it](https://github.com/davafons/kiln/blob/main/.github/workflows/docs.yml).

## Committed output

To serve the site from a directory in the repository, set `output` to it:

```ruby
config.output = "docs"
```

A successful build replaces that directory entirely, so keep nothing else in it. CI can check that the committed output is current, by building and failing when Git sees a difference:

```sh
RAILS_ENV=production bin/rails kiln:build
test -z "$(git status --porcelain docs)"
```

This needs a build that renders the same bytes every time, which [`kiln_build(repeatable: true)`](/testing/#kiln_build) checks in tests.
