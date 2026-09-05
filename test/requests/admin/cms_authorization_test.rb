require "test_helper"

class Admin::CmsAuthorizationTest < ActionDispatch::IntegrationTest
  test "anonymous sessions cannot reach any Phase 4 controller" do
    assert_cms_redirects_to(new_admin_session_path)
  end

  test "password-only sessions cannot reach any Phase 4 controller" do
    user = admin_users(:owner)
    post admin_session_path, params: {
      admin_login: { email: user.email, password: TEST_PASSWORD }
    }

    assert_cms_redirects_to(admin_totp_challenge_path)
  end

  test "server HTML exposes every locale when JavaScript is unavailable" do
    sign_in_as_admin
    get new_admin_project_path

    assert_response :success
    assert_select "[role='tabpanel']", count: 3
    assert_select "[role='tabpanel'][hidden]", count: 0
    assert_select "button[type='button'][role='tab']", count: 3
  end

  private

  def assert_cms_redirects_to(destination)
    [
      -> { get admin_projects_path },
      -> { get admin_posts_path },
      -> { get admin_tags_path },
      -> { get edit_admin_profile_path },
      -> { get edit_admin_resume_path },
      -> { delete admin_project_cover_image_path(0) },
      -> { delete admin_project_gallery_image_path(0, 0) },
      -> { delete admin_post_cover_image_path(0) },
      -> { delete admin_profile_portrait_path },
      -> { delete admin_resume_pdf_path(0) },
      -> {
        post admin_markdown_preview_path,
          params: { preview: { markdown: "Text", frame_id: "post_en_markdown_preview" } }
      }
    ].each do |request|
      request.call
      assert_redirected_to destination
    end
  end
end
