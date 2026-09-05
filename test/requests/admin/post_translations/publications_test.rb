# frozen_string_literal: true

require "test_helper"

class Admin::PostTranslations::PublicationsTest < ActionDispatch::IntegrationTest
  setup do
    @post = Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "Post", slug: "post", excerpt: "Excerpt", body_markdown: "Body" }
    })
    @translation = @post.translations.first
    sign_in_as_admin
  end

  test "creates, updates, and destroys a post translation publication" do
    post admin_post_translation_publication_path(@translation)
    assert_redirected_to edit_admin_post_path(@post), status: :see_other
    assert_predicate @translation.reload, :published?

    patch admin_post_translation_publication_path(@translation), params: {
      publication: { scheduled_at: 2.hours.from_now.iso8601, scheduled_at_local: "" }
    }
    assert_response :see_other
    assert_predicate @translation.reload, :scheduled?

    delete admin_post_translation_publication_path(@translation)
    assert_response :see_other
    assert_predicate @translation.reload, :draft?

    get edit_admin_post_path(@post)
    assert_select "form form", count: 0
  end
end
