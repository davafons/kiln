module Kiln
  module Content
    class Entry
      # SLUG.md, or SLUG.LOCALE.md for a translation. A locale is two lowercase letters, optionally
      # followed by a dash and two uppercase letters: es, ja, pt-BR.
      FILENAME = /\A(?<name>.+?)(?:\.(?<locale>[a-z]{2}(?:-[A-Z]{2})?))?\.md\z/
      # A leading YYYY-MM-DD or YYYY-MM date. The slug is the rest of the name, or the whole name when
      # it is only a date. A month-only date means the 1st of that month.
      DATED = /\A(?<date>\d{4}-\d{2}(?:-\d{2})?)(?:-(?<slug>.+))?\z/

      attr_reader :collection, :path, :slug, :locale, :attributes, :body, :published_at

      def initialize(collection, path)
        @collection, @path = collection&.to_s, Pathname(path)
        match = FILENAME.match(@path.basename.to_s) or raise ArgumentError, "#{@path} is not a Markdown file: its name must end in .md"
        @locale = match[:locale]
        dated = DATED.match(match[:name])
        @slug = (dated && dated[:slug]) || match[:name]
        text = @path.read
        @attributes, @body = Frontmatter.parse(text)
        @frontmatter_lines = text.delete_suffix(body).count("\n")
        @published_at = attributes["published_at"] || (filename_date(dated[:date]) if dated)
        @translations = {}
      end

      # The visible translation from SLUG.LOCALE.md, or nil.
      def translation(locale)
        entry = @translations[locale.to_s]
        entry if entry && (Content.show_drafts || entry.published?)
      end

      def add_translation(entry) = @translations[entry.locale] = entry

      def title = attributes["title"] || slug.titleize
      def draft? = attributes["draft"] == true
      def scheduled? = published_at.present? && published_at.in_time_zone.future?
      def published? = !draft? && !scheduled?

      def html
        return Markdown.render(body, path:, line_offset: @frontmatter_lines).html_safe if Content.source_positions
        @html ||= Markdown.render(body).html_safe
      end

      def to_param = slug
      def [](key) = attributes[key.to_s]
      def to_h = attributes

      def respond_to_missing?(name, include_private = false) = attributes.key?(name.to_s) || super

      def method_missing(name, *args)
        attributes.key?(name.to_s) && args.empty? ? attributes[name.to_s] : super
      end

      private
        def filename_date(date)
          Date.iso8601(date.length == 7 ? "#{date}-01" : date)
        rescue Date::Error
          raise ArgumentError, "#{path} starts with an invalid date: #{date}"
        end
    end
  end
end
