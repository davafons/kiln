require "erb"

module Kiln
  # Writes redirect responses as a _redirects file (Cloudflare Pages, Netlify) and/or meta refresh pages
  # (GitHub Pages).
  class Redirects
    Entry = Data.define(:from, :to, :status)

    FILENAME = "_redirects"

    # Reads a _redirects file. Missing file means no rules.
    def self.load(file)
      return [] unless File.file?(file)

      File.readlines(file, chomp: true).filter_map do |line|
        from, to, status = line.strip.split(/\s+/)
        next if from.nil? || from.start_with?("#") || to.nil?

        Entry.new(from:, to:, status: Integer(status || 302, exception: false) || 302)
      end
    end

    def initialize(entries, mode:, writer:, host:, url: nil)
      @entries = entries.map { it.with(to: relativize(it.to, host)) }
      @mode = mode
      @writer = writer
      @url = url
    end

    def write(output)
      files = []
      files << write_file(output) if %i[file both].include?(@mode)
      files.concat(write_pages) if %i[meta_refresh both].include?(@mode)
      files
    end

    private
      # Rules from a copied public/_redirects come first, so hand-written rules win.
      def write_file(output)
        file = Pathname(output).join(FILENAME)
        existing = file.exist? ? file.read.chomp.then { it.empty? ? "" : "#{it}\n" } : ""
        File.write(file, existing + @entries.map { "#{it.from} #{it.to} #{it.status}\n" }.join)
        FILENAME
      end

      def write_pages
        @entries.map do |entry|
          @writer.write_file(@writer.file_for(entry.from, "text/html"), page(entry.to))
        end
      end

      def page(to)
        canonical = ERB::Util.html_escape(@url && to.start_with?("/") ? "#{@url.chomp("/")}#{to}" : to)
        to = ERB::Util.html_escape(to)
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
          <meta charset="utf-8">
          <title>Redirecting</title>
          <meta http-equiv="refresh" content="0; url=#{to}">
          <link rel="canonical" href="#{canonical}">
          </head>
          <body><a href="#{to}">#{to}</a></body>
          </html>
        HTML
      end

      def relativize(location, host)
        uri = URI.parse(location)
        return location unless uri.is_a?(URI::HTTP) && uri.host&.casecmp?(host)

        "#{uri.path.presence || "/"}#{"?#{uri.query}" if uri.query}#{"##{uri.fragment}" if uri.fragment}"
      rescue URI::InvalidURIError
        location
      end
  end
end
