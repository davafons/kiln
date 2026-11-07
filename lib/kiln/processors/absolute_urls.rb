module Kiln
  module Processors
    # Prefixes root-relative image URLs with config.url: img src/srcset and og:/twitter: image meta tags.
    # Feed readers and social previews need absolute URLs.
    module AbsoluteUrls
      IMG_TAG = /<img\b[^>]*>/
      IMAGE_META = /<meta\b(?=[^>]*\s(?:property|name)="(?:og|twitter):image[^"]*")[^>]*>/
      ROOT_RELATIVE = %r{\A/(?!/)}

      def self.call(html, context)
        base = context.config.url.to_s.chomp("/")
        raise Kiln::Error, "config.url is required when absolute_urls is on" if base.empty?

        html
          .gsub(IMG_TAG) { |tag| tag.gsub(/(?<=\s)(src|srcset)="([^"]*)"/) { %(#{$1}="#{$1 == "src" ? absolute($2, base) : srcset($2, base)}") } }
          .gsub(IMAGE_META) { |tag| tag.sub(/(?<=\s)content="([^"]*)"/) { %(content="#{absolute($1, base)}") } }
      end

      def self.absolute(url, base) = url.match?(ROOT_RELATIVE) ? "#{base}#{url}" : url

      def self.srcset(value, base)
        value.gsub(/(\A|,)(\s*)([^\s,]+)/) { "#{$1}#{$2}#{absolute($3, base)}" }
      end
    end
  end
end
