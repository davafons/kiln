require "json"

module Kiln
  # The URLs a page points at, as written in its HTML. The asset export and the verifier both read
  # pages through this.
  module Links
    ATTRIBUTES = %w[href src srcset].freeze
    ELEMENTS = "//*[@href or @src or @srcset]"

    # URLs in an element's href, src and srcset attributes.
    def self.in(element)
      ATTRIBUTES.flat_map do |name|
        value = element[name]
        next [] if value.nil?

        name == "srcset" ? value.split(",").filter_map { it.split.first } : [ value ]
      end
    end

    # Module URLs in an importmap's imports and scopes, or nil when the JSON is not an importmap.
    def self.importmap(json)
      map = JSON.parse(json)
      urls = map.fetch("imports", {}).values + map.fetch("scopes", {}).values.flat_map(&:values)
      urls if urls.all?(String)
    rescue JSON::ParserError, NoMethodError, TypeError
      nil
    end
  end
end
