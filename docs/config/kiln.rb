Kiln.configure do |config|
  config.url = "https://kiln.davafons.com"
  config.cname = true
  config.not_found = "/404"
end

Kiln.pages do
  # One route serves every page. The list is a lambda because config/kiln.rb loads before
  # config/initializers/pages.rb defines Docs::PAGES.
  params :page, slug: -> { Docs::PAGES.map(&:slug) }
end
