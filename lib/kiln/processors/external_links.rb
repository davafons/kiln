module Kiln
  module Processors
    # Adds target="_blank" rel="noopener" to http(s) links that point to another host.
    module ExternalLinks
      LINK_TAG = /<a\b[^>]*\shref="https?:[^"]*"[^>]*>/

      def self.call(html, context)
        host = context.config.host
        html.gsub(LINK_TAG) { |tag| external?(tag, host) ? mark(tag) : tag }
      end

      def self.external?(tag, host)
        link_host = URI(tag[/(?<=\s)href="([^"]*)"/, 1]).host
        link_host.present? && !link_host.casecmp?(host)
      rescue URI::InvalidURIError
        false
      end

      def self.mark(tag)
        tag = tag.sub(/(?<=\s)rel="([^"]*)"/) { $1.split.include?("noopener") ? $& : %(rel="#{$1} noopener") }
        additions = [ (' target="_blank"' unless tag.match?(/\starget=/)), (' rel="noopener"' unless tag.match?(/\srel=/)) ]
        tag.delete_suffix(">") + additions.join + ">"
      end
    end
  end
end
