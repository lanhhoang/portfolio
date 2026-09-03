# frozen_string_literal: true

class MarkdownRenderer
  ALLOWED_TAGS = %w[
    a blockquote br code del em h1 h2 h3 h4 h5 h6 hr li ol p pre
    strong table tbody td th thead tr ul
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href title class start].freeze

  # ponytail: Commonmarker 2.x enables header anchors + syntect highlighting by
  # default; header_ids: nil and syntax_highlighter: nil turn both off.
  def self.call(markdown)
    html = Commonmarker.to_html(
      markdown.to_s,
      options: {
        render: { unsafe: false, github_pre_lang: false },
        extension: { strikethrough: true, table: true, tagfilter: true, header_ids: nil }
      },
      plugins: { syntax_highlighter: nil }
    )

    Rails::HTML5::SafeListSanitizer.new.sanitize(
      html,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end
end
