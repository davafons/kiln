module Kiln
  module Content
    # ActionView template handlers. A handler returns Ruby source that evaluates to the output.
    module Handlers
      # Plain Markdown never changes between renders, so convert it once at compile time.
      Markdown = ->(_template, source) { "#{Content::Markdown.render(source).inspect}.html_safe" }

      # ERB fills a fresh output buffer, then its result goes through Markdown on every render.
      # "begin;" keeps the ERB source on its original line numbers.
      MarkdownERB = ->(template, source) do
        erb = ActionView::Template.registered_template_handler(:erb).call(template, source)
        "Kiln::Content::Markdown.render(begin;#{erb}\nend.to_s).html_safe"
      end
    end
  end
end
