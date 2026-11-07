# Known limits

These are things Kiln does not do today.

- Pages render one at a time.
- Redirects are written only as `_redirects`, which Cloudflare Pages and Netlify read. GitHub Pages ignores the file, so redirect routes do not redirect there.
- Wildcard rules in your own `public/_redirects` are written out, but the link checker and `kiln:serve` only follow exact rules.
- JavaScript modules are found through the importmap. Relative `import "./x.js"` between files is not followed.
- Collections read `*.md` files. `.md.erb` works for views only.
- Only GET routes are built. Forms, sessions and anything else that needs a server do not work on a static host.
- The link checker covers internal links, anchors and importmap modules. External links are not checked.
- Kiln adds no dev server for writing pages. Use `bin/rails server`, with whatever reloading the app already has.
