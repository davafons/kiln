module Kiln
  class Configuration
    # Output directory, relative to Rails.root unless absolute.
    attr_accessor :output
    # Public base URL ("https://davafons.com"). Sets the request host and enables sitemap.xml.
    attr_accessor :url
    # :directory ("/now" -> now/index.html) or :file ("/now" -> now.html).
    attr_accessor :paths
    # Writes a CNAME file with this domain when set. true takes the host from `url`.
    attr_accessor :cname
    # Path rendered to 404.html (expected to respond with 404 or 200), nil to skip.
    attr_accessor :not_found
    # CSS selectors for sample markup whose links the verifier ignores (for example component demos).
    attr_accessor :verify_skip
    # Extra files that aren't routes: { "octicons-license.txt" => "vendor/octicons/LICENSE" }.
    # Sources are relative to Rails.root.
    attr_accessor :files

    def initialize
      @output = "dist"
      @url = nil
      @paths = :directory
      @cname = nil
      @not_found = nil
      @verify_skip = []
      @files = {}
    end

    # Host sent with every request: the host of `url`, or "localhost".
    def host
      (url && URI(url).host) || "localhost"
    end

    def output_path(root = Rails.root)
      Pathname(output).absolute? ? Pathname(output) : Pathname(root).join(output)
    end
  end
end
