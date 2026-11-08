# Kiln content layer: Markdown views (.html.md, .html.md.erb), collections of Markdown files with
# YAML frontmatter, and single Markdown files. Optional and independent of the exporter, so
# server-rendered Rails apps can use it too. Load it with `require "kiln/content"` after adding the
# commonmarker and rouge gems. The content page of the docs (docs/app/views/pages/content.html.md)
# describes every feature; comments here cover only what the code does not show.
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
      attr_writer :root, :show_drafts, :source_positions

      def root
        Pathname(@root || Rails.root.join("content"))
      end

      def show_drafts
        return @show_drafts unless @show_drafts.nil?
        Rails.env.development? && !Kiln.building?
      end

      def source_positions
        return false if Kiln.building?
        @source_positions == true
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

      # One Markdown file anywhere, such as a README or CONTRIBUTING.md, as an entry with
      # frontmatter, html and source positions. Read again when the file changes, once per build.
      def file(path)
        path = Pathname(path).expand_path
        if Kiln.building?
          Kiln.build_cache.fetch("kiln/content/file/#{path}") { Entry.new(nil, path) }
        else
          mtime = path.mtime
          cached = files[path]
          cached && cached[0] == mtime ? cached[1] : (files[path] = [ mtime, Entry.new(nil, path) ])[1]
        end
      end

      def reset!
        @root = @show_drafts = @source_positions = nil
        @collections = {}
        @files = {}
      end

      private
        def collections
          @collections ||= {}
        end

        def files
          @files ||= {}
        end
    end
  end
end

ActionDispatch::ExceptionWrapper.rescue_responses["Kiln::Content::NotFound"] = :not_found

ActiveSupport.on_load(:action_view) do
  ActionView::Template.register_template_handler :md, Kiln::Content::Handlers::Markdown
  ActionView::Template.register_template_handler :"md.erb", Kiln::Content::Handlers::MarkdownERB
end
