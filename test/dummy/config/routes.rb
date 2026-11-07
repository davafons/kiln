Rails.application.routes.draw do
  root "pages#home"
  get "about", to: "pages#about", as: :about
  get "posts", to: "posts#index", as: :posts
  get "posts/:slug", to: "posts#show", as: :post
  get "feed.xml", to: "posts#feed", as: :feed, defaults: { format: :xml }
  get "health.json", to: "pages#health", as: :health, defaults: { format: :json }
  get "old-about", to: redirect("/about"), as: :old_about
  get "search", to: "pages#search", as: :search
  get "private", to: "pages#private_page", as: :private_page
  get "not-found", to: "pages#not_found", as: :not_found
  mount ->(env) { [ 200, { "content-type" => "text/plain" }, [ "pong" ] ] }, at: "/ping.txt"

  get "up" => "rails/health#show", as: :rails_health_check
end
