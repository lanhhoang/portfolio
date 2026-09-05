require "test_helper"

class Admin::ProfilesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  test "renders an empty editor without persisting a row" do
    assert_no_difference "Profile.count" do
      get edit_admin_profile_path
    end
    assert_response :success
  end

  test "first update creates the singleton plus its English translation" do
    patch admin_profile_path, params: { profile: profile_params }

    profile = Profile.current
    assert_redirected_to edit_admin_profile_path, status: :see_other
    assert_equal "en", profile.translations.sole.locale
    assert_equal "orange", profile.accent
  end

  test "second update keeps the same rows" do
    create_profile
    translation = Profile.current.translations.sole

    assert_no_difference [ "Profile.count", "ProfileTranslation.count" ] do
      patch admin_profile_path, params: { profile: profile_params.merge(
        translations_attributes: { "0" => { id: translation.id, locale: "en", display_name: "Owner", headline: "Ideas. Interfaces. Impact.", introduction: "Short intro", biography_markdown: "# Biography", availability_label: "Available" } }
      ) }
    end

    assert_redirected_to edit_admin_profile_path
  end

  test "removes blank social values from the stored JSON" do
    patch admin_profile_path, params: { profile: profile_params }

    assert_equal({ "github" => "https://github.com/owner", "website" => "https://example.test" }, Profile.current.social_links)
  end

  test "invalid accent returns 422 while preserving entered biography" do
    patch admin_profile_path, params: { profile: profile_params.merge(accent: "neon") }

    assert_response :unprocessable_entity
    assert_select "textarea", text: /Biography/
    assert_select "[role='alert']"
  end

  test "invalid portrait upload returns 422 with text retained" do
    patch admin_profile_path, params: { profile: profile_params.merge(
      portrait: Rack::Test::UploadedFile.new(Rails.root.join("Gemfile"), "text/plain")
    ) }

    assert_response :unprocessable_entity
    assert_select "textarea", text: /Biography/
  end

  test "does not let nested updates move a persisted translation to another locale" do
    create_profile
    translation = Profile.current.translations.sole

    patch admin_profile_path, params: { profile: profile_params.merge(
      translations_attributes: { "0" => { id: translation.id, locale: "vi", display_name: "X", headline: "X", introduction: "X", biography_markdown: "X", availability_label: "X" } }
    ) }

    assert_response :see_other
    assert_equal "en", translation.reload.locale
  end

  test "rejects a malformed profile scope" do
    patch admin_profile_path, params: { profile: "not-an-object" }
    assert_response :bad_request
  end

  test "purges the portrait through the dedicated resource after the singleton exists" do
    create_profile
    Profile.current.portrait.attach(io: Rails.root.join("public/icon.png").open, filename: "portrait.png", content_type: "image/png")
    attachment_id = Profile.current.portrait.attachment.id

    delete admin_profile_portrait_path

    assert_redirected_to edit_admin_profile_path
    refute ActiveStorage::Attachment.exists?(attachment_id)
  end

  test "renders portrait removal as a standalone delete form" do
    create_profile
    Profile.current.portrait.attach(io: Rails.root.join("public/icon.png").open, filename: "portrait.png", content_type: "image/png")

    get edit_admin_profile_path
    assert_select "form[action='#{admin_profile_portrait_path}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
    assert_select "form form", count: 0
    assert_select "a[data-turbo-method='delete']", count: 0
  end

  test "requires authentication" do
    sign_out_admin
    get edit_admin_profile_path
    assert_redirected_to new_admin_session_path
  end

  private

  def create_profile
    Profile.create!(public_contact_email: "owner@example.test", accent: "lime", translations_attributes: {
      "0" => { locale: "en", display_name: "Portfolio Owner", headline: "H", introduction: "I", biography_markdown: "B", availability_label: "A" }
    })
  end

  def profile_params
    {
      public_contact_email: "hello@example.test", accent: "orange",
      social_links: { github: "https://github.com/owner", linkedin: "", website: "https://example.test" },
      translations_attributes: {
        "0" => { locale: "en", display_name: "Portfolio Owner", headline: "Ideas. Interfaces. Impact.", introduction: "Short intro", biography_markdown: "# Biography", availability_label: "Available" }
      }
    }
  end
end
