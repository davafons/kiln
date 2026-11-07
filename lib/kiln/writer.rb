require "fileutils"

module Kiln
  # Maps request paths to files under the output directory and writes them.
  class Writer
    def initialize(output, mode:)
      raise Kiln::Error, "Unknown paths mode #{mode.inspect} (expected :directory or :file)" unless %i[directory file].include?(mode)

      @output = Pathname(output).expand_path
      @mode = mode
    end

    # Relative file for a request path: "/now" -> "now/index.html" (or "now.html" in :file mode).
    def file_for(path, content_type)
      segments = segments_for(path)
      content_type = content_type.to_s.split(";").first.to_s.strip.downcase
      return "index.html" if segments.empty?

      name = segments.last
      if File.extname(name).empty?
        if content_type == "text/html"
          segments = @mode == :directory ? [ *segments, "index.html" ] : [ *segments[...-1], "#{name}.html" ]
        elsif (extension = extension_for(content_type))
          segments = [ *segments[...-1], "#{name}.#{extension}" ]
        end
      end
      segments.join("/")
    end

    def write(path, content_type, body)
      write_file(file_for(path, content_type), body)
    end

    # Writes a file at a path relative to the output directory.
    def write_file(relative, body)
      target = @output.join(relative).expand_path
      unless target.to_s.start_with?("#{@output}/")
        raise Kiln::Error, "Refusing to write #{relative} outside #{@output}"
      end

      FileUtils.mkdir_p(target.dirname)
      File.binwrite(target, body)
      relative.to_s
    end

    private
      def extension_for(content_type)
        symbol = Mime::Type.lookup(content_type).symbol if content_type.present?
        symbol == :text ? "txt" : symbol
      end

      def segments_for(path)
        segments = path.to_s.split("?").first.to_s.split("/").reject(&:empty?).map do
          Rack::Utils.unescape_path(it).force_encoding(Encoding::UTF_8)
        end
        if segments.any? { it == ".." || it == "." || it.include?("/") || it.include?("\0") }
          raise Kiln::Error, "Invalid path #{path.inspect}"
        end
        segments
      end
  end
end
