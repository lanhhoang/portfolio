require "test_helper"

class Admin::MarkdownPreviewsTest < ActionDispatch::IntegrationTest
  test "requires the fully authenticated owner" do
    post admin_markdown_preview_path, params: { preview: { markdown: "# Draft", frame_id: "post_en_markdown_preview" } }
    assert_redirected_to new_admin_session_path
  end

  test "renders sanitized markdown in the requested turbo frame" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: {
      preview: { markdown: "# Safe\n\n<script>alert(1)</script>\n\n```ruby\nputs :ok\n```", frame_id: "post_en_markdown_preview" }
    }, headers: { "Turbo-Frame" => "post_en_markdown_preview" }

    assert_response :success
    assert_select "turbo-frame#post_en_markdown_preview[data-markdown-preview-target='frame']" do
      assert_select "h1", text: "Safe"
      assert_select "pre code", text: /puts :ok/
      assert_select "script", count: 0
    end
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "rejects a frame id outside the admin naming contract" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: { preview: { markdown: "Text", frame_id: "bad id<script>" } }
    assert_response :unprocessable_entity
  end

  test "rejects a malformed parameter scope without raising" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: { preview: "not-an-object" }
    assert_response :bad_request
  end
end
