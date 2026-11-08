require "erb"

module Kiln
  # sitemap.xml with every indexable HTML page in the manifest.
  class Sitemap
    FILENAME = "sitemap.xml"

    def self.noindex?(response, body)
      return false unless response.html?
      return true if response.headers["x-robots-tag"].to_s.downcase.include?("noindex")
      return false unless body.match?(/noindex/i)

      Nokogiri::HTML5(body).css("meta[name]").any? do |meta|
        meta["name"].casecmp?("robots") && meta["content"].to_s.downcase.include?("noindex")
      end
    end

    def initialize(manifest, url:)
      @manifest = manifest
      @url = url.chomp("/")
    end

    def write(output)
      urls = @manifest.entries.filter_map do |path, entry|
        next if entry[:noindex] || entry[:content_type] != "text/html"

        "  <url><loc>#{ERB::Util.html_escape(@url + served_path(path, entry[:file]))}</loc></url>\n"
      end

      File.write(Pathname(output).join(FILENAME), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        #{urls.join}</urlset>
      XML
      FILENAME
    end

    private
      def served_path(path, file)
        File.basename(file.to_s) == "index.html" ? "/#{file.to_s.delete_suffix("index.html")}" : path
      end
  end
end
