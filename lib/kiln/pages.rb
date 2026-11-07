module Kiln
  # Declarations from config/kiln.rb: param sources and skips, keyed by route name.
  # STUB: the router work fills in validation, paginate, and anything else the router needs.
  class Pages
    attr_reader :sources, :skips

    def initialize
      @sources = {}
      @skips = {}
    end

    def params(route_name, source)
      @sources[route_name.to_sym] = source
    end

    def skip(route_name, reason: nil)
      @skips[route_name.to_sym] = reason
    end
  end
end
