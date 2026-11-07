# Kiln content layer: Markdown views and Markdown collections with YAML frontmatter.
# Optional and independent of the exporter, so server-rendered Rails apps can use it too.
#
#   # Gemfile
#   gem "commonmarker"
#   gem "rouge"
#
#   # config/initializers/kiln.rb
#   require "kiln/content"
#
# Markdown views. app/views/pages/about.html.md renders through the layout like any view.
# about.html.md.erb runs ERB first, then Markdown. commonmarker renders GitHub Flavored Markdown
# (tables, strikethrough, autolinks, heading ids). Code blocks are highlighted by Rouge with CSS
# classes, so add a Rouge theme to your stylesheet (`rougify style github`).
#
# Collections. content/blog/2024-05-01-hello.md:
#
#   ---
#   title: Hello
#   tags: [rails]
#   ---
#   # Hello
#
#   posts = Kiln::Content.collection("blog")
#   posts.all                     # visible entries, newest first
#   posts.find("hello")           # raises Kiln::Content::NotFound (a 404 in Rails)
#   posts.find_by(slug: "hello")  # or nil
#   post.slug, post.title, post.published_at, post.draft?, post.body, post.html, post[:tags], post.tags
#
#   # config/kiln.rb
#   params :post, -> { Kiln::Content.collection("blog").map { { slug: it.slug } } }
#
# Publishing. Entries with `draft: true` or a future `published_at` (frontmatter or filename date)
# are hidden. They show in development unless Kiln is building; set Kiln::Content.show_drafts to
# override. A server-rendered app can share a hidden entry with
# `posts.find(params[:slug], preview_token: params[:token])`, where the token is `post.preview_token`.
#
# Source positions. With Kiln::Content.source_positions on, each rendered block of a .md view or
# collection entry carries data-tensaku-md="path:startLine:startCol-endLine:endCol" for the Tensaku
# editor. .md.erb views get none. It defaults to on in development when Tensaku is loaded, and is
# always off while Kiln is building.
#
# Settings: Kiln::Content.root (default Rails.root/content), Kiln::Content.show_drafts,
# Kiln::Content.preview_secret (default secret_key_base), Kiln::Content.source_positions.
begin
  require "commonmarker"
  require "rouge"
rescue LoadError => error
  raise LoadError, "kiln/content needs the commonmarker and rouge gems. " \
    "Add `gem \"commonmarker\"` and `gem \"rouge\"` to your Gemfile. (#{error.message})"
end

require "kiln"
require "action_dispatch"
require_relative "content/markdown"
require_relative "content/frontmatter"
require_relative "content/handlers"
require_relative "content/entry"
require_relative "content/collection"

module Kiln
  module Content
    class NotFound < Kiln::Error; end

    class << self
      attr_writer :root, :show_drafts, :preview_secret, :source_positions

      def root
        Pathname(@root || Rails.root.join("content"))
      end

      def show_drafts
        return @show_drafts unless @show_drafts.nil?
        Rails.env.development? && !Kiln.building?
      end

      def source_positions
        return false if Kiln.building?
        return @source_positions unless @source_positions.nil?
        Rails.env.development? && !defined?(::Tensaku).nil?
      end

      def preview_secret
        @preview_secret || Rails.application.secret_key_base
      end

      def collection(name)
        dir = root.join(name.to_s)
        if Kiln.building?
          Kiln.build_cache.fetch("kiln/content/#{dir}") { Collection.new(name, dir) }
        else
          cached = collections[dir]
          cached.nil? || cached.stale? ? collections[dir] = Collection.new(name, dir) : cached
        end
      end

      def reset!
        @root = @show_drafts = @preview_secret = @source_positions = nil
        @collections = {}
      end

      private
        def collections
          @collections ||= {}
        end
    end
  end
end

ActionDispatch::ExceptionWrapper.rescue_responses["Kiln::Content::NotFound"] = :not_found

ActiveSupport.on_load(:action_view) do
  ActionView::Template.register_template_handler :md, Kiln::Content::Handlers::Markdown
  ActionView::Template.register_template_handler :"md.erb", Kiln::Content::Handlers::MarkdownERB
end
