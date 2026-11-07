module Kiln
  # Collects every problem found during a build so they can be printed together.
  class Report
    Entry = Data.define(:kind, :message, :path)

    KINDS = %i[uncovered_route render asset broken_link missing_anchor importmap redirect write hook other].freeze

    attr_reader :errors, :warnings, :written

    def initialize
      @errors = []
      @warnings = []
      @written = []
      @mutex = Mutex.new
    end

    def error(kind, message, path: nil)
      @mutex.synchronize { @errors << Entry.new(kind:, message:, path:) }
    end

    def warn(kind, message, path: nil)
      @mutex.synchronize { @warnings << Entry.new(kind:, message:, path:) }
    end

    # Records a file written to the output (relative path).
    def wrote(file)
      @mutex.synchronize { @written << file.to_s }
    end

    def success? = errors.empty?
    def failure? = !success?

    def to_s(title: "Kiln build")
      lines = []
      warnings.each { lines << "warning #{format_entry(it)}" }
      if errors.any?
        lines << "" if warnings.any?
        lines << "#{title} failed with #{errors.size} #{"error".pluralize(errors.size)}:"
        errors.group_by(&:kind).each do |kind, entries|
          lines << ""
          lines << "  #{kind.to_s.humanize} (#{entries.size})"
          entries.each { lines << "    #{format_entry(it)}" }
        end
      else
        lines << "#{title} succeeded: #{written.size} #{"file".pluralize(written.size)} written."
      end
      lines.join("\n")
    end

    private
      def format_entry(entry)
        entry.path ? "#{entry.path}: #{entry.message}" : entry.message
      end
  end
end
