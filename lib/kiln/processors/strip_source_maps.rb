module Kiln
  module Processors
    # Removes sourceMappingURL comments from JavaScript and CSS.
    module StripSourceMaps
      COMMENT = %r{//[#@] sourceMappingURL=[^\r\n]*|/\*[#@] sourceMappingURL=[^*]*\*/}
      # A comment on its own line goes with its line break; one after code leaves the line intact.
      PATTERN = /^[ \t]*(?:#{COMMENT})[ \t]*(?:\r?\n|\z)|(?:#{COMMENT})/

      def self.call(text)
        text.gsub(PATTERN, "")
      end
    end
  end
end
