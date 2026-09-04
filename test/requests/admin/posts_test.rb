require "test_helper"

class Admin::PostsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as_admin
    @tag = Tag.create!(translations_attributes: {
      "0" => { locale: "en", name: "Writing" }
    })
  end

  test "requires authentication" do
    sign_out_admin
    get admin_posts_path
    assert_redirected_to new_admin_session_path
  end

  test "creates English and Vietnamese translations while rejecting a blank French tab" do
    assert_difference "PostTranslation.count", 2 do
      post admin_posts_path, params: { post: {
        tag_ids: [@tag.id],
        cover_image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"),
        translations_attributes: {
          "0" => { locale: "en", title: "A careful post", slug: "", excerpt: "English excerpt", body_markdown: "# English" },
          "1" => { locale: "fr", title: "", slug: "", excerpt: "", body_markdown: "" },
          "2" => { locale: "vi", title: "Bài viết", slug: "bai-viet", excerpt: "Tóm tắt", body_markdown: "# Tiếng Việt" }
        }
      } }
    end

    post = Post.order(:id).last
    assert_redirected_to edit_admin_post_path(post), status: :see_other
    assert_equal %w[draft draft], post.translations.order(:locale).pluck(:state)
    assert_equal "a-careful-post", post.translations.find_by!(locale: "en").slug
    assert post.cover_image.attached?
    assert_equal [@tag.id], post.tag_ids
  end

  test "renders entered values and upload errors with 422" do
    post admin_posts_path, params: { post: {
      cover_image: Rack::Test::UploadedFile.new(Rails.root.join("Gemfile"), "text/plain"),
      translations_attributes: { "0" => { locale: "en", title: "Draft title", slug: "", excerpt: "E", body_markdown: "# Body" } }
    } }

    assert_response :unprocessable_entity
    assert_select "input[value='Draft title']"
    assert_select "[role='alert']", text: /cover image/i
  end

  test "title-only update leaves the old slug" do
    post_record = create_post
    translation = post_record.translations.find_by!(locale: "en")
    patch admin_post_path(post_record), params: { post: {
      translations_attributes: { "0" => { id: translation.id, locale: "en", title: "Renamed", slug: translation.slug, excerpt: "E", body_markdown: "B" } }
    } }

    assert_redirected_to edit_admin_post_path(post_record)
    assert_equal "existing-post", translation.reload.slug
  end

  test "explicitly edited slug persists" do
    post_record = create_post
    translation = post_record.translations.find_by!(locale: "en")
    patch admin_post_path(post_record), params: { post: {
      translations_attributes: { "0" => { id: translation.id, locale: "en", title: "Renamed", slug: "editor-choice", excerpt: "E", body_markdown: "B" } }
    } }

    assert_redirected_to edit_admin_post_path(post_record)
    assert_equal "editor-choice", translation.reload.slug
  end

  test "does not let nested updates move a persisted translation to another locale" do
    post_record = create_post
    translation = post_record.translations.create!(
      locale: "fr", title: "Article", slug: "article", excerpt: "Extrait", body_markdown: "Corps"
    )
    patch admin_post_path(post_record), params: { post: {
      translations_attributes: { "0" => { id: translation.id, locale: "vi", title: "Article", slug: "article", excerpt: "Extrait", body_markdown: "Corps" } }
    } }

    assert_response :see_other
    assert_equal "fr", translation.reload.locale
  end

  test "rejects a malformed post scope" do
    post admin_posts_path, params: { post: "not-an-object" }
    assert_response :bad_request
  end

  test "purges the cover through the dedicated resource" do
    post_record = create_post
    post_record.cover_image.attach(io: Rails.root.join("public/icon.png").open, filename: "cover.png", content_type: "image/png")
    attachment_id = post_record.cover_image.attachment.id

    delete admin_post_cover_image_path(post_record)

    assert_redirected_to edit_admin_post_path(post_record)
    refute ActiveStorage::Attachment.exists?(attachment_id)
  end

  test "renders destructive actions as standalone delete forms" do
    post_record = create_post
    post_record.cover_image.attach(io: Rails.root.join("public/icon.png").open, filename: "cover.png", content_type: "image/png")

    get admin_posts_path
    assert_delete_form admin_post_path(post_record)
    assert_select "a[data-turbo-method='delete']", count: 0

    get edit_admin_post_path(post_record)
    assert_delete_form admin_post_cover_image_path(post_record)
    assert_select "form form", count: 0
  end

  test "destroys a post with a 303 redirect" do
    post_record = create_post
    assert_difference("Post.count", -1) { delete admin_post_path(post_record) }
    assert_redirected_to admin_posts_path, status: :see_other
  end

  private

  def create_post
    Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "Existing Post", slug: "existing-post", excerpt: "Excerpt", body_markdown: "Body" }
    })
  end

  def assert_delete_form(path)
    assert_select "form[action='#{path}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
  end
end
