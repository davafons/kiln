module Docs
  Page = Data.define(:slug, :title, :group, :description) do
    def template = slug || "introduction"
  end

  # The sidebar, in order. Each page is app/views/pages/<template>.html.md. The introduction is the
  # home page: its slug is nil, which leaves the route's optional segment empty.
  PAGES = [
    Page.new(nil, "Introduction", "Start", "What Kiln does, with a small example."),
    Page.new("installation", "Installation", "Start", "Add Kiln to a Rails app and run a first build."),
    Page.new("pages", "Pages", "Guides", "Routes, param sources, pagination, skips, redirects and non-HTML routes."),
    Page.new("views", "Views and assets", "Guides", "Build-time helpers, asset export, and the checks for development markup."),
    Page.new("content", "Markdown", "Guides", "Markdown views, collections, translations and drafts."),
    Page.new("testing", "Testing", "Guides", "Build the site in Minitest and assert on single pages."),
    Page.new("deploying", "Deploying", "Guides", "Cloudflare Pages, GitHub Pages and committed output."),
    Page.new("configuration", "Configuration", "Reference", "Every option of Kiln.configure."),
    Page.new("build", "Build", "Reference", "Commands, build steps, output files and error messages."),
    Page.new("limits", "Known limits", "Reference", "What Kiln does not do.")
  ].freeze

  def self.page(slug) = PAGES.find { it.slug == slug }
end
