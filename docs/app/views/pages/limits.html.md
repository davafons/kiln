# Known limits

Kiln does not do the following today.

- Only GET routes are built. Forms, sessions and anything else that needs a server do not work on a static host.
- Pages render one at a time.
- Kiln adds no dev server. Use `bin/rails server`, with whatever reloading the app already has.
- Redirects are written only as `_redirects`. GitHub Pages ignores that file, so redirect routes do not redirect there.
- Wildcard rules in your own `public/_redirects` are written out, but the link check and `kiln:serve` only follow exact rules.
- The link check covers internal links, anchors and importmap modules. External links are not checked.
- JavaScript modules are found through the importmap. Relative `import "./x.js"` between files is not followed.
- Collections read `*.md` files. `.md.erb` works for views only.
- `kiln:serve` answers `/about` directly where a static host redirects to `/about/`, so a relative link can resolve differently there than on the host.
