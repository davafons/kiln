module Kiln
  module Content
    class Entry
      FILENAME = /\A(?:(?<date>\d{4}-\d{2}-\d{2})-)?(?<slug>.+?)\.md\z/

      attr_reader :collection, :path, :slug, :attributes, :body, :published_at

      def initialize(collection, path)
        @collection, @path = collection.to_s, Pathname(path)
        match = FILENAME.match(@path.basename.to_s)
        @slug = match[:slug]
        @attributes, @body = Frontmatter.parse(@path.read)
        @published_at = attributes["published_at"] || (Date.iso8601(match[:date]) if match[:date])
      end

      def title = attributes["title"] || slug.titleize
      def draft? = attributes["draft"] == true
      def scheduled? = published_at.present? && published_at.in_time_zone.future?
      def published? = !draft? && !scheduled?
      def html = @html ||= Markdown.render(body).html_safe
      def to_param = slug
      def [](key) = attributes[key.to_s]
      def to_h = attributes

      def preview_token
        OpenSSL::HMAC.hexdigest("SHA256", Content.preview_secret, "#{collection}/#{slug}")
      end

      def respond_to_missing?(name, include_private = false) = attributes.key?(name.to_s) || super

      def method_missing(name, *args)
        attributes.key?(name.to_s) && args.empty? ? attributes[name.to_s] : super
      end
    end
  end
end
