class Post
  include ActiveModel::Model
  attr_accessor :slug, :title, :body

  ALL = [
    { slug: "hello-world", title: "Hello, world", body: "First post." },
    { slug: "second-post", title: "Second post", body: "Another one." }
  ].freeze

  def self.all = ALL.map { new(**it) }
  def self.find(slug) = all.find { it.slug == slug } || raise(ActionController::RoutingError, "No post #{slug}")
  def to_param = slug
end
