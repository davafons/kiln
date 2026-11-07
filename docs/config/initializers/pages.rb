module Docs
  Page = Data.define(:slug, :title, :group, :description)

  # The sidebar, in order. Each page is app/views/pages/<slug>.html.md.
  PAGES = [
    Page.new("introduction", "Introduction", "Start", "What Kiln does and how a build works."),
    Page.new("installation", "Installation", "Start", "Add Kiln to a Rails app and run a first build."),
    Page.new("pages", "Declaring pages", "Build", "Routes, param sources, pagination, skips, redirects and non-HTML routes."),
    Page.new("views", "Writing views", "Build", "Build-time helpers, assets, and the guards against development markup."),
    Page.new("content", "Markdown content", "Build", "Markdown views, collections, translations and drafts."),
    Page.new("testing", "Testing", "Build", "Build the site in Minitest and assert on single pages."),
    Page.new("deploying", "Deploying", "Build", "Cloudflare Pages, GitHub Pages and checks in CI."),
    Page.new("configuration", "Configuration", "Reference", "Every option, and what every build does."),
    Page.new("limits", "Known limits", "Reference", "What Kiln does not do.")
  ].freeze

  def self.page(slug) = PAGES.find { it.slug == slug }
end
