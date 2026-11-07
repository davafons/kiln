module Kiln
  module Content
    # ActionView template handlers. A handler returns Ruby source that evaluates to the output.
    module Handlers
      # Plain Markdown never changes between renders, so convert it once at compile time. Source
      # positions are a development aid, so that variant renders on each request.
      Markdown = ->(template, source) do
        positioned = "Kiln::Content::Markdown.render(#{source.inspect}, path: #{template.identifier.inspect})"
        "(Kiln::Content.source_positions ? #{positioned} : #{Content::Markdown.render(source).inspect}).html_safe"
      end

      # ERB fills a fresh output buffer, then its result goes through Markdown on every render.
      # "begin;" keeps the ERB source on its original line numbers. No source positions: after ERB,
      # Markdown lines no longer match the lines in the template file.
      MarkdownERB = ->(template, source) do
        erb = ActionView::Template.registered_template_handler(:erb).call(template, source)
        "Kiln::Content::Markdown.render(begin;#{erb}\nend.to_s).html_safe"
      end
    end
  end
end
