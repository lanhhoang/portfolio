require "test_helper"

class Admin::TagsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  test "requires authentication" do
    sign_out_admin
    get admin_tags_path
    assert_redirected_to new_admin_session_path
  end

  test "creates English and French translations while rejecting the blank Vietnamese tab" do
    assert_difference "TagTranslation.count", 2 do
      post admin_tags_path, params: { tag: { translations_attributes: {
        "0" => { locale: "en", name: "Web performance", slug: "" },
        "1" => { locale: "fr", name: "Performance web", slug: "performance-web" },
        "2" => { locale: "vi", name: "", slug: "" }
      } } }
    end

    tag = Tag.order(:id).last
    assert_redirected_to admin_tags_path, status: :see_other
    assert_equal %w[en fr], tag.translations.order(:locale).pluck(:locale)
  end

  test "blank English returns 422 with the French value preserved" do
    post admin_tags_path, params: { tag: { translations_attributes: {
      "0" => { locale: "en", name: "", slug: "" },
      "1" => { locale: "fr", name: "Performance web", slug: "performance-web" }
    } } }

    assert_response :unprocessable_entity
    assert_select "input[value='Performance web']"
  end

  test "duplicate French slug returns 422" do
    Tag.create!(translations_attributes: { "0" => { locale: "en", name: "First" } })
    Tag.create!(translations_attributes: {
      "0" => { locale: "en", name: "Second" },
      "1" => { locale: "fr", name: "Second FR", slug: "second" }
    })
    first_french = Tag.first.translations.create!(locale: "fr", name: "Premier", slug: "premier")

    post admin_tags_path, params: { tag: { translations_attributes: {
      "0" => { locale: "en", name: "Third", slug: "" },
      "1" => { locale: "fr", name: "Third FR", slug: first_french.slug }
    } } }

    assert_response :unprocessable_entity
  end

  test "renaming a tag does not rewrite its slug but an explicit slug update works" do
    tag = Tag.create!(translations_attributes: { "0" => { locale: "en", name: "Ruby on Rails", slug: "ruby-on-rails" } })
    translation = tag.translations.find_by!(locale: "en")

    patch admin_tag_path(tag), params: { tag: { translations_attributes: {
      "0" => { id: translation.id, locale: "en", name: "Rails", slug: "ruby-on-rails" }
    } } }
    assert_redirected_to admin_tags_path
    assert_equal "ruby-on-rails", translation.reload.slug

    patch admin_tag_path(tag), params: { tag: { translations_attributes: {
      "0" => { id: translation.id, locale: "en", name: "Rails", slug: "rails-framework" }
    } } }
    assert_redirected_to admin_tags_path
    assert_equal "rails-framework", translation.reload.slug
  end

  test "does not let nested updates move a persisted translation to another locale" do
    tag = Tag.create!(translations_attributes: { "0" => { locale: "en", name: "Ruby" } })
    translation = tag.translations.create!(locale: "fr", name: "Ruby FR", slug: "ruby-fr")

    patch admin_tag_path(tag), params: { tag: { translations_attributes: {
      "0" => { id: translation.id, locale: "vi", name: "Ruby VI", slug: "ruby-vi" }
    } } }

    assert_response :see_other
    assert_equal "fr", translation.reload.locale
  end

  test "rejects a malformed tag scope" do
    post admin_tags_path, params: { tag: "not-an-object" }
    assert_response :bad_request
  end

  test "destroy removes the tag and its taggings but not associated projects" do
    tag = Tag.create!(translations_attributes: { "0" => { locale: "en", name: "Rails" } })
    project = Project.create!(role: "Engineer", tag_ids: [ tag.id ], translations_attributes: {
      "0" => { locale: "en", title: "Tagged", slug: "tagged", summary: "S", body_markdown: "B" }
    })

    assert_difference("Tag.count", -1) { delete admin_tag_path(tag) }
    assert_redirected_to admin_tags_path, status: :see_other
    assert Project.exists?(project.id)
    assert_empty project.reload.tags
  end

  test "renders destructive actions as standalone delete forms" do
    tag = Tag.create!(translations_attributes: { "0" => { locale: "en", name: "Rails" } })

    get admin_tags_path
    assert_select "form[action='#{admin_tag_path(tag)}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
    assert_select "a[data-turbo-method='delete']", count: 0
  end
end
