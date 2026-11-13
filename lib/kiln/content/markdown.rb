module Kiln
  module Content
    module Markdown
      OPTIONS = {
        # Commonmarker turns hardbreaks on by default. Off, a line break inside a paragraph is a
        # space, as CommonMark says, so files wrapped at a column read as whole paragraphs.
        render: { unsafe: true, hardbreaks: false },
        extension: { table: true, strikethrough: true, autolink: true, header_ids: "" }
      }.freeze
      PLUGINS = { syntax_highlighter: nil }.freeze
      # header_ids also appends an empty anchor link to every heading. Headings keep only the id;
      # the app decides how to link them.
      HEADING_ANCHOR = %r{<a href="#[^"]*" aria-label="[^"]*" data-heading-content="[^"]*" class="anchor"></a>}

      # With a path, block elements carry their source position. line_offset is the number of lines
      # above the text in that file, such as frontmatter.
      def self.render(text, path: nil, line_offset: 0)
        options = path ? OPTIONS.deep_merge(render: { sourcepos: true }) : OPTIONS
        document = Commonmarker.parse(text.to_s, options:)
        document.walk { highlight(it, sourcepos: path) if it.type == :code_block }
        html = document.to_html(options:, plugins: PLUGINS).gsub(HEADING_ANCHOR, "")
        path ? SourcePosition.rewrite(html, path, line_offset) : html
      end

      # Renders text that is a single paragraph without the wrapping <p>, for titles and captions.
      # Text with any other block structure renders as with render.
      def self.render_inline(text)
        html = render(text)
        block = Commonmarker.parse(text.to_s, options: OPTIONS).first_child
        return html unless block&.type == :paragraph && block.next_sibling.nil?

        html.delete_prefix("<p>").delete_suffix("</p>\n")
      end

      # Swaps a code block for raw HTML highlighted by Rouge, with CSS classes and no inline styles.
      # data-language keeps the fence's language as written, also when Rouge has no lexer for it.
      def self.highlight(node, sourcepos:)
        code = node.string_content
        language = node.fence_info.split.first.to_s
        lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
        attributes = +""
        attributes << %( data-language="#{ERB::Util.html_escape(language)}") unless language.empty?
        attributes << %( data-sourcepos="%d:%d-%d:%d") % node.source_position.values_at(:start_line, :start_column, :end_line, :end_column) if sourcepos
        html = %(<pre class="highlight #{lexer.tag}"#{attributes}><code>#{Rouge::Formatters::HTML.new.format(lexer.lex(code))}</code></pre>\n)
        node.replace(Commonmarker::Node.new(:html_block, literal: html))
      end
    end

    # Editor markup: data-md-source="path:startLine:startCol-endLine:endCol", with the path relative
    # to Rails.root, 1-based lines and commonmarker byte columns with an inclusive end. Only the
    # elements in BLOCKS carry it; commonmarker's positions on inline elements are dropped. This is
    # the one place that writes it.
    module SourcePosition
      BLOCKS = %w[p h1 h2 h3 h4 h5 h6 ul ol li blockquote pre table hr].to_set.freeze
      ATTRIBUTE = /<(\w+)([^>]*?) data-sourcepos="(\d+):(\d+)-(\d+):(\d+)"/

      def self.rewrite(html, path, line_offset)
        relative = ERB::Util.html_escape(Pathname(path).relative_path_from(Rails.root).to_s)
        html.gsub(ATTRIBUTE) do
          tag, rest = $1, $2
          next "<#{tag}#{rest}" unless BLOCKS.include?(tag)

          %(<#{tag}#{rest} data-md-source="#{relative}:#{$3.to_i + line_offset}:#{$4}-#{$5.to_i + line_offset}:#{$6}")
        end
      end
    end
  end
end
