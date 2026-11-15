module Kiln
  # Maps a URL path to a file the way Cloudflare static assets do by default (auto-trailing-slash).
  # "/x" serves the file x or x.html, and "/x/" serves x/index.html. The other spellings of a page
  # redirect to the URL it is served at: "/x/" and "/x.html" to "/x", "/x/index.html" and "/x" to
  # "/x/" when only x/index.html exists. Never returns a file outside root.
  class StaticResolver
    def initialize(root)
      @root = Pathname(root).expand_path
    end

    # The file served at the path, or nil.
    def resolve(url_path)
      segments, slash = parse(url_path)
      return unless segments

      base = @root.join(*segments)

      candidates =
        if segments.empty? || slash then [ base.join("index.html") ]
        elsif segments.last.end_with?(".html") then []
        else [ base, Pathname("#{base}.html") ]
        end
      candidates.find { servable?(it) }
    end

    # The URL the path redirects to, or nil. Only meaningful when resolve returns nil.
    def redirect(url_path)
      segments, slash = parse(url_path)
      return if segments.nil? || segments.empty?

      base = @root.join(*segments)
      *parents, name = segments
      target =
        if slash
          segments if servable?(Pathname("#{base}.html"))
        elsif name == "index.html"
          [ *parents, "" ] if servable?(base)
        elsif name.end_with?(".html") && name != ".html"
          [ *parents, name.delete_suffix(".html") ] if servable?(base)
        else
          [ *segments, "" ] if servable?(base.join("index.html"))
        end
      "/#{target.map { Rack::Utils.escape_path(it) }.join("/")}" if target
    end

    private
      # The decoded segments and whether the path ends in a slash, or nil for a path that can't name
      # a file under root.
      def parse(url_path)
        path = Rack::Utils.unescape_path(url_path.to_s.split(/[?#]/, 2).first.to_s)
        return if path.include?("\0")

        segments = path.split("/").reject { it.empty? || it == "." }
        [ segments, path.end_with?("/") ] unless segments.include?("..")
      rescue ArgumentError, Encoding::CompatibilityError
        nil
      end

      def servable?(file)
        file.file? && file.realpath.to_s.start_with?("#{@root.realpath}/")
      rescue ArgumentError, Encoding::CompatibilityError
        false
      end
  end
end
