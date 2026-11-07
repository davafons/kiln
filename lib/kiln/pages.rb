module Kiln
  # Declarations from config/kiln.rb: param sources and skips, keyed by route name.
  class Pages
    attr_reader :sources, :skips

    def initialize
      @sources = {}
      @skips = {}
    end

    # params :post, -> { Post.all.map { { slug: it.slug } } }
    # params :health, locale: [ nil, "es", "ja" ]
    #
    # Value lists build every combination of their values. A nil value leaves the key out, for
    # optional segments such as "(:locale)". A list may be a lambda, called at build time.
    def params(route_name, source = nil, **values)
      if values.any?
        raise ArgumentError, "params :#{route_name} takes a source or value lists, not both" if source
        source = -> { combinations(values) }
      end
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

    private
      def combinations(values)
        lists = values.map { |key, list| (list.respond_to?(:call) ? list.call : list).to_a.map { { key => it } } }
        lists.first.product(*lists.drop(1)).map { it.reduce(:merge).compact }
      end
  end
end
