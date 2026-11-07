module Kiln
  module Content
    class Collection
      include Enumerable

      attr_reader :name

      def initialize(name, dir)
        @name, @dir = name.to_s, Pathname(dir)
        @stamp = stamp
        translations, entries = files.map { Entry.new(@name, it) }.partition(&:locale)
        @entries = entries.sort_by { [ it.published_at&.in_time_zone || Time.at(0), it.slug ] }.reverse
        translations.each { attach(it) }
      end

      # Visible entries, newest first.
      def all
        Content.show_drafts ? @entries : @entries.select(&:published?)
      end

      def each(&) = all.each(&)

      def find(slug) = find_by(slug:) || raise(NotFound, "no #{name} entry with slug #{slug.inspect}")

      def find_by(slug:) = all.find { it.slug == slug.to_s }

      # True when files were added, removed or changed since loading.
      def stale? = stamp != @stamp

      private
        def files = Dir[@dir.join("*.md")].sort

        def attach(translation)
          entry = @entries.find { it.slug == translation.slug }
          raise ArgumentError, "#{translation.path} is a translation, but no entry has the slug #{translation.slug.inspect}" unless entry

          entry.add_translation(translation)
        end

        def stamp = files.map { [ it, File.mtime(it) ] }
    end
  end
end
