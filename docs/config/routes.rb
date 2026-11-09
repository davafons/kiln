Rails.application.routes.draw do
  get "llms", to: "pages#llms", defaults: { format: :text }
  get "404", to: "pages#not_found"
  get "(:slug)", to: "pages#show", as: :page, constraints: { slug: Regexp.union(Docs::PAGES.filter_map(&:slug)) }
end
