module Kiln
  # Checks the built output: internal links, anchors and importmap modules.
  class Verifier
    LINK_ATTRIBUTES = %w[href src srcset].freeze

    def initialize(output, config:)
      @output = Pathname(output)
      @host = config.host.downcase
      @resolver = StaticResolver.new(@output)
      @redirect_sources = Redirects.load(@output.join(Redirects::FILENAME)).map(&:from).to_set
      @anchors = {}
    end

    def verify(report)
      @errors = Set.new
      Dir.glob("**/*.html", base: @output).sort.each { check_page(it) }
      @errors.each { |kind, message, path| report.error(kind, message, path:) }
      report
    end

    private
      def check_page(file)
        page = page_path(file)
        doc = parse(@output.join(file))

        doc.xpath("//*[@href or @src or @srcset]").each do |element|
          urls_in(element).each { check_link(it, page) }
        end
        doc.css('script[type="importmap"]').each { check_importmap(it.text, page) }
      end

      def urls_in(element)
        LINK_ATTRIBUTES.flat_map do |name|
          value = element[name]
          next [] if value.nil?

          name == "srcset" ? value.split(",").filter_map { it.split.first } : [ value ]
        end
      end

      def check_link(url, page)
        uri = internal_uri(url, page) or return
        target = @resolver.resolve(uri.path)

        if target.nil?
          error(:broken_link, url, page) unless @redirect_sources.include?(uri.path)
        elsif uri.fragment.present? && uri.fragment != "top" && target.extname == ".html"
          fragment = Rack::Utils.unescape_path(uri.fragment)
          error(:missing_anchor, url, page) unless anchors(target).include?(fragment)
        end
      rescue URI::Error
        error(:broken_link, url, page)
      end

      def check_importmap(json, page)
        map = JSON.parse(json)
        urls = map.fetch("imports", {}).values + map.fetch("scopes", {}).values.flat_map(&:values)
        urls.each do |url|
          uri = internal_uri(url, page)
          error(:importmap, url, page) if uri && @resolver.resolve(uri.path).nil?
        rescue URI::Error
          error(:importmap, url, page)
        end
      rescue JSON::ParserError, NoMethodError, TypeError
        error(:importmap, "invalid importmap JSON", page)
      end

      # The URL resolved against the page, or nil when it points somewhere Kiln doesn't serve.
      def internal_uri(url, page)
        url = url.strip
        return if url.empty?

        uri = URI.join("https://#{@host}#{page}", url)
        uri if uri.is_a?(URI::HTTP) && uri.host.to_s.downcase == @host
      end

      def anchors(file)
        @anchors[file] ||= parse(file).xpath("//*[@id]/@id | //a[@name]/@name").to_set(&:value)
      end

      def parse(file)
        Nokogiri::HTML5(file.read)
      end

      # The URL a file is served at: index.html -> /, now/index.html -> /now/, components.html -> /components.
      def page_path(file)
        path = "/#{file}"
        return path.delete_suffix("index.html") if File.basename(file) == "index.html"

        path.delete_suffix(".html")
      end

      def error(kind, message, page)
        @errors << [ kind, message, page ]
      end
  end
end
