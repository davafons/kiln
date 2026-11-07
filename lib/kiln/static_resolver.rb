module Kiln
  # Maps a URL path to a file the way Cloudflare Pages and GitHub Pages do: exact file, then x.html,
  # then x/index.html. A trailing slash only matches x/index.html. Never returns a file outside root.
  class StaticResolver
    def initialize(root)
      @root = Pathname(root).expand_path
    end

    def resolve(url_path)
      path = Rack::Utils.unescape_path(url_path.to_s.split(/[?#]/, 2).first.to_s)
      return if path.include?("\0")

      segments = path.split("/").reject { it.empty? || it == "." }
      return if segments.include?("..")

      base = @root.join(*segments)
      candidates = path.end_with?("/") || segments.empty? ? [ base.join("index.html") ] : [ base, Pathname("#{base}.html"), base.join("index.html") ]
      candidates.find { it.file? && inside_root?(it) }
    rescue ArgumentError, Encoding::CompatibilityError
      nil
    end

    private
      def inside_root?(file)
        file.realpath.to_s.start_with?("#{@root.realpath}/")
      end
  end
end
