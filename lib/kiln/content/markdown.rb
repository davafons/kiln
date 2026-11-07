module Kiln
  module Content
    module Markdown
      EXTENSIONS = { fenced_code_blocks: true, tables: true, autolink: true, strikethrough: true }.freeze

      class Renderer < Redcarpet::Render::HTML
        def block_code(code, language)
          lexer = Rouge::Lexer.find_fancy(language.to_s, code) || Rouge::Lexers::PlainText.new
          %(<pre class="highlight #{lexer.tag}"><code>#{Rouge::Formatters::HTML.new.format(lexer.lex(code))}</code></pre>\n)
        end
      end

      # A new parser per call: Redcarpet parsers aren't safe to share between threads.
      def self.render(text)
        Redcarpet::Markdown.new(Renderer.new(with_toc_data: true), EXTENSIONS).render(text.to_s)
      end
    end
  end
end
