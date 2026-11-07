# Deploying

The output is a directory of plain files. Any static host can serve it. This page covers the files hosts care about and two common setups.

## What a host reads

| File | Written when | Read by |
|---|---|---|
| `404.html` | `not_found` is set | Cloudflare Pages, GitHub Pages and Netlify serve it for unknown paths. |
| `_redirects` | A route redirects, or `public/_redirects` exists | Cloudflare Pages and Netlify. GitHub Pages ignores it. |
| `CNAME` | `cname` is set | GitHub Pages, for a custom domain. |
| `sitemap.xml` | `url` is set | Search engines. |

With the default `paths: :directory`, `/about` is written to `about/index.html`. Cloudflare Pages and GitHub Pages both serve that file at `/about`, and `bin/rails kiln:serve` resolves paths the same way.

## Cloudflare Pages

Cloudflare Pages reads `_redirects`, so redirect routes work there. Build in CI and upload the output with Wrangler:

```sh
RAILS_ENV=production bin/rails kiln:build
npx wrangler pages deploy dist --project-name=my-site
```

## GitHub Pages

GitHub Pages serves `404.html` and reads `CNAME`, but ignores `_redirects`. A redirect route still builds, and the rule is written, but the old path answers with the 404 page. Keep redirect routes out of a site deployed there, or use a host that reads the file.

This site deploys to GitHub Pages from a workflow. It builds on every push to `main` that changes the docs or Kiln itself:

```yaml
# .github/workflows/docs.yml
jobs:
  build:
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: docs
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
          working-directory: docs
      - run: bin/rails kiln:build
        env:
          RAILS_ENV: production
      - uses: actions/upload-pages-artifact@v5
        with:
          path: docs/dist

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

The repository's Pages setting must use GitHub Actions as its source.

## Committed output

Some repositories commit the built site, for example to serve it from a `docs/` folder. CI can check that the committed output is current: build, then fail when Git sees a difference.

```sh
RAILS_ENV=production bin/rails kiln:build
test -z "$(git status --porcelain docs)"
```

Set `output` to the committed directory, such as `config.output = "docs"`. Kiln wipes that directory at the start of every build, so keep nothing else in it. A build that renders the same bytes as last time leaves Git with nothing to report, which is what `kiln_build(repeatable: true)` checks in tests.
