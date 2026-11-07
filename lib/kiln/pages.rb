module Kiln
  # Declarations from config/kiln.rb: param sources and skips, keyed by route name.
  class Pages
    attr_reader :sources, :skips

    def initialize
      @sources = {}
      @skips = {}
    end

    # params :post, -> { Post.all.map { { slug: it.slug } } }
    def params(route_name, source)
      raise ArgumentError, "params :#{route_name} needs a callable source" unless source.respond_to?(:call)
      @sources[route_name.to_sym] = source
    end

    def skip(route_name, reason: nil)
      @skips[route_name.to_sym] = reason
    end

    # paginate :posts_page, per: 10, total: -> { Post.count }
    # Builds pages start..last, where last is ceil(total / per). The start page is always built, so an
    # empty list still gets its first page. Use start: 2 when page 1 lives at another route.
    def paginate(route_name, per:, total:, param: :page, start: 1)
      raise ArgumentError, "paginate :#{route_name} needs a positive per:" unless per.is_a?(Integer) && per.positive?

      params route_name, -> do
        last = Integer(total.call).fdiv(per).ceil
        (start..[ start, last ].max).map { { param => it } }
      end
    end

    def declared_names = (sources.keys + skips.keys).uniq
  end
end
