# frozen_string_literal: true

require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  test "renders technical Markdown" do
    html = MarkdownRenderer.call("## Example\n\n```ruby\nputs :ok\n```")

    assert_includes html, "<h2>Example</h2>"
    assert_includes html, '<code class="language-ruby">'
    assert_includes html, "puts :ok"
  end

  test "removes raw HTML scripts event handlers and unsafe link protocols" do
    # Blank lines keep each construct in its own block: a type-1 HTML block
    # (script/pre/style) otherwise swallows the rest of the document.
    markdown = <<~MARKDOWN
      <script>alert(1)</script>

      <img src=x onerror="alert(2)">

      [unsafe](javascript:alert(3))

      [safe](https://example.test/docs)
    MARKDOWN

    html = MarkdownRenderer.call(markdown)

    assert_not_includes html, "<script"
    assert_not_includes html, "onerror"
    assert_not_includes html, "javascript:"
    assert_includes html, 'href="https://example.test/docs"'
  end
end
