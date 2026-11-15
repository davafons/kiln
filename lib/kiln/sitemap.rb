require "erb"

module Kiln
  # sitemap.xml with every indexable HTML page in the manifest, and a robots.txt that points to it.
  class Sitemap
    FILENAME = "sitemap.xml"
    ROBOTS = "robots.txt"

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

    # Returns the relative file written.
    def write(writer)
      urls = @manifest.entries.filter_map do |path, entry|
        next if entry[:noindex] || entry[:content_type] != "text/html"

        "  <url><loc>#{ERB::Util.html_escape(@url + path)}</loc></url>\n"
      end

      writer.write_file(FILENAME, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        #{urls.join}</urlset>
      XML
    end

    # robots.txt that allows everything and points crawlers at the sitemap.
    def write_robots(writer)
      writer.write_file(ROBOTS, "User-agent: *\nAllow: /\n\nSitemap: #{@url}/#{FILENAME}\n")
    end
  end
end
