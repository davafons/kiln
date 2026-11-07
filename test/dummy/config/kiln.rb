Kiln.configure do |config|
  config.url = "https://example.com"
  config.not_found = "/not-found"
end

Kiln.pages do
  params :post, -> { Post.all.map { { slug: it.slug } } }
  params :contact, locale: [ nil, "es", "ja" ]
  skip :search, reason: "dynamic"
end
