module Kiln
  # Writes redirect responses as a _redirects file (Cloudflare Pages, Netlify).
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

    def initialize(entries, host:)
      @entries = entries.map { it.with(to: relativize(it.to, host)) }
    end

    # Rules from a copied public/_redirects come first, so hand-written rules win. Returns the filename.
    def write(writer)
      file = writer.output.join(FILENAME)
      existing = file.exist? ? file.read.chomp.then { it.empty? ? "" : "#{it}\n" } : ""
      writer.write_file(FILENAME, existing + @entries.map { "#{it.from} #{it.to} #{it.status}\n" }.join)
    end

    private
      def relativize(location, host)
        uri = URI.parse(location)
        return location unless uri.is_a?(URI::HTTP) && uri.host&.casecmp?(host)

        "#{uri.path.presence || "/"}#{"?#{uri.query}" if uri.query}#{"##{uri.fragment}" if uri.fragment}"
      rescue URI::InvalidURIError
        location
      end
  end
end
