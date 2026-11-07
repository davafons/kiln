module Kiln
  # Walks the app's GET routes and turns them into concrete pages, using the param sources and skips
  # from Kiln.pages. Routes that need params but have no source are reported as uncovered.
  class Router
    # status is :built (count pages), :skipped (reason) or :uncovered.
    Row = Data.define(:name, :path, :status, :count, :reason)

    # Framework routes skipped by default, keyed by "controller#action" or a whole "controller".
    DEFAULT_SKIPS = {
      "rails/health#show" => "Rails health check",
      "turbo/native/navigation" => "turbo-rails native navigation"
    }.freeze

    def initialize(routes, pages, report:)
      @routes = routes
      @dsl = pages
      @report = report
    end

    def pages
      analyze
      @pages
    end

    def rows
      analyze
      @rows
    end

    private
      attr_reader :dsl, :report

      def analyze
        return if @rows

        @pages = []
        @rows = []
        seen = Set.new
        check_declared_names
        get_routes.each do |route|
          status, detail = classify(route)
          count = 0
          if status == :built
            pages_for(route, detail).each do |page|
              next unless seen.add?(page.path)
              @pages << page
              count += 1
            end
          end
          @rows << Row.new(name: route.name, path: route.path.spec.to_s, status:, count:, reason: status == :skipped ? detail : nil)
        end
      end

      def get_routes
        @get_routes ||= @routes.routes.select { it.verb.empty? || it.verb.split("|").include?("GET") }
      end

      # Explicit declarations win over the defaults. For :built, detail is the param list source.
      def classify(route)
        name = route.name&.to_sym
        if name && dsl.skips.key?(name)
          [ :skipped, dsl.skips[name] || "skipped in config/kiln.rb" ]
        elsif name && dsl.sources.key?(name)
          [ :built, dsl.sources[name] ]
        elsif route.internal || route.path.spec.to_s.start_with?("/rails/")
          [ :skipped, "Rails internal route" ]
        elsif (reason = default_skip(route))
          [ :skipped, reason ]
        elsif route.app.engine?
          [ :skipped, "mounted engine" ]
        elsif route.required_parts.empty?
          [ :built, -> { [ {} ] } ]
        else
          report_uncovered(route)
          [ :uncovered, nil ]
        end
      end

      def default_skip(route)
        controller, action = route.requirements.values_at(:controller, :action)
        DEFAULT_SKIPS["#{controller}##{action}"] || DEFAULT_SKIPS[controller] if controller
      end

      def pages_for(route, source)
        list = source.call
        unless list.is_a?(Enumerable) && !list.is_a?(Hash)
          return source_error(route, "must return a list of hashes, got #{list.class}")
        end

        list.flat_map do |params|
          next source_error(route, "returned #{params.inspect}, expected a hash") unless params.is_a?(Hash)

          params = params.symbolize_keys.compact
          missing = route.required_parts - params.keys
          next source_error(route, "returned #{params.inspect}, missing #{missing.map(&:inspect).join(", ")}") if missing.any?

          [ Page.new(path: route.format(params.transform_values(&:to_param)), route_name: route.name, params:) ]
        end
      rescue StandardError => error
        source_error(route, "raised #{error.class}: #{error.message}")
      end

      def source_error(route, message)
        report.error(:other, "Param source for :#{route.name} #{message}")
        []
      end

      def report_uncovered(route)
        spec = route.path.spec.to_s
        message =
          if route.name
            keys = route.required_parts.map { "#{it}: ..." }.join(", ")
            "GET #{spec} (:#{route.name}) needs params. Add `params :#{route.name}, -> { [ { #{keys} } ] }` " \
              "or `skip :#{route.name}, reason: \"...\"` to config/kiln.rb."
          else
            "GET #{spec} needs params but has no name. Add `as:` to the route in config/routes.rb, " \
              "then declare its params or skip it in config/kiln.rb."
          end
        report.error(:uncovered_route, message)
      end

      def check_declared_names
        (dsl.declared_names - get_routes.filter_map { it.name&.to_sym }).each do |name|
          report.error(:other, "config/kiln.rb declares :#{name}, but there is no GET route with that name")
        end
      end
  end
end
