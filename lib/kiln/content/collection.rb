module Kiln
  module Content
    class Collection
      include Enumerable

      attr_reader :name

      def initialize(name, dir)
        @name, @dir = name.to_s, Pathname(dir)
        @stamp = stamp
        @entries = files.map { Entry.new(@name, it) }
          .sort_by { [ it.published_at&.in_time_zone || Time.at(0), it.slug ] }.reverse
      end

      # Visible entries, newest first.
      def all
        Content.show_drafts ? @entries : @entries.select(&:published?)
      end

      def each(&) = all.each(&)

      def find(slug, preview_token: nil)
        entry = @entries.find { it.slug == slug.to_s }
        return entry if entry && (Content.show_drafts || entry.published? || preview?(entry, preview_token))
        raise NotFound, "no #{name} entry with slug #{slug.inspect}"
      end

      def find_by(slug:) = all.find { it.slug == slug.to_s }

      # True when files were added, removed or changed since loading.
      def stale? = stamp != @stamp

      private
        def files = Dir[@dir.join("*.md")].sort

        def stamp = files.map { [ it, File.mtime(it) ] }

        def preview?(entry, token)
          token.present? && ActiveSupport::SecurityUtils.secure_compare(entry.preview_token, token.to_s)
        end
    end
  end
end
