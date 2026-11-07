module Kiln
  # HTML transforms applied to every rendered HTML response, in order: built-ins, then config.processors.
  # Processors edit the HTML as a string and leave everything they don't match byte-for-byte intact.
  module Processors
    Context = Data.define(:path, :config, :response)

    def self.apply(html, context)
      config = context.config
      html = StripCSRF.call(html, context)
      html = AbsoluteUrls.call(html, context) if config.absolute_urls
      html = ExternalLinks.call(html, context) if config.external_links

      config.processors.reduce(html) do |current, processor|
        result = processor.call(current, context)
        unless result.is_a?(String)
          raise Kiln::Error, "Processor #{processor.inspect} returned #{result.class} for #{context.path}, expected a String"
        end
        result
      end
    end
  end
end
