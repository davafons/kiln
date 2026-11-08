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
    # params :archive, -> { Archive.all.map { { year: it.year } } }, locale: [ nil, "es" ]
    #
    # Value lists build every combination of their values. A nil value leaves the key out, for
    # optional segments such as "(:locale)". A list may be a lambda, called at build time. With both a
    # source and value lists, every hash from the source is combined with every combination.
    def params(route_name, source = nil, **values)
      raise ArgumentError, "params :#{route_name} needs a callable source" unless source.nil? || source.respond_to?(:call)
      raise ArgumentError, "params :#{route_name} needs a source or value lists" if source.nil? && values.empty?

      @sources[route_name.to_sym] =
        if values.empty? then source
        elsif source.nil? then -> { combinations(values) }
        else -> { source.call.to_a.product(combinations(values)).map { |params, extra| params.merge(extra) } }
        end
    end

    def skip(route_name, reason: nil)
      @skips[route_name.to_sym] = reason
    end

    def declared_names = (sources.keys + skips.keys).uniq

    private
      def combinations(values)
        lists = values.map { |key, list| (list.respond_to?(:call) ? list.call : list).to_a.map { { key => it } } }
        lists.first.product(*lists.drop(1)).map { it.reduce(:merge).compact }
      end
  end
end
