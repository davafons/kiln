# Kiln

Kiln fires a Rails app into a static site. Build pages with normal Rails (routes, controllers, views,
helpers, Turbo, Stimulus), then run:

```sh
RAILS_ENV=production bin/rails kiln:build
```

Kiln renders every GET route through Rack and writes plain files to `dist/` that any static host can
serve. Routes are the single source of truth, and the build fails loudly.

> Status: work in progress towards 0.1.0. See [PLAN.md](PLAN.md).

## License

MIT. See [LICENSE](LICENSE).
