module Kiln
  module Content
    module Frontmatter
      PATTERN = /\A---[ \t]*\r?\n(.*?)^---[ \t]*(?:\r?\n|\z)/m

      # Returns [attributes, body]. Attributes have string keys.
      def self.parse(text)
        match = PATTERN.match(text)
        return [ {}, text ] unless match

        attributes = YAML.safe_load(match[1], permitted_classes: [ Date, Time, Symbol ]) || {}
        raise ArgumentError, "frontmatter must be a YAML mapping" unless attributes.is_a?(Hash)

        [ attributes.transform_keys(&:to_s), match.post_match ]
      end
    end
  end
end
