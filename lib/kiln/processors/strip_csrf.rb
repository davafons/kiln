module Kiln
  module Processors
    # Removes authenticity_token inputs and the csrf-param / csrf-token meta tags, leaving the page as
    # Rails renders it with forgery protection off. A static page has no session to check tokens against.
    module StripCSRF
      TOKEN_INPUT = /<input\b(?=[^>]*\bname="authenticity_token")[^>]*>/
      # The newline csrf_meta_tags puts between its two tags goes with the first one.
      META_TAG = /<meta\b(?=[^>]*\sname="csrf-(?:param|token)")[^>]*>(?:\n(?=<meta\b[^>]*\sname="csrf-))?/

      def self.call(html)
        html.gsub(TOKEN_INPUT, "").gsub(META_TAG, "")
      end
    end
  end
end
