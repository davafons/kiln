Rails.application.routes.draw do
  root "pages#landing"

  get "llms", to: "pages#llms", defaults: { format: :text }
  get "404", to: "pages#not_found"
  get ":slug", to: "pages#show", as: :page, constraints: { slug: Regexp.union(Docs::PAGES.map(&:slug)) }
end
