Kiln.configure do |config|
  config.url = "https://example.com"
  config.not_found = "/not-found"
  # test/kiln/tasks_test.rb runs kiln:build in a subprocess: KILN_OUTPUT keeps it in a temp dir,
  # and KILN_FAIL adds a missing file so the build fails.
  config.output = ENV["KILN_OUTPUT"] if ENV["KILN_OUTPUT"]
  config.files = { "missing.txt" => "missing.txt" } if ENV["KILN_FAIL"]
end

Kiln.pages do
  params :post, -> { Post.all.map { { slug: it.slug } } }
  params :contact, locale: [ nil, "es", "ja" ]
  skip :search, reason: "dynamic"
end
