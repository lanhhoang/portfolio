require "test_helper"

class Admin::ProjectsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as_admin
    @tag = Tag.create!(translations_attributes: {
      "0" => { locale: "en", name: "Rails" }
    })
  end

  test "creates shared fields, tags, image, and localized translations" do
    assert_difference "Project.count", 1 do
      assert_difference "ProjectTranslation.count", 2 do
        post admin_projects_path, params: { project: {
          role: "Lead developer", started_on: "2026-01-01", ended_on: "2026-06-01",
          live_url: "https://example.test", source_url: "https://github.com/example/work",
          featured_position: "1", tag_ids: [ @tag.id ],
          cover_image: image_upload,
          translations_attributes: {
            "0" => { locale: "en", title: "Useful Work", slug: "", summary: "English summary", body_markdown: "# English" },
            "1" => { locale: "fr", title: "Travail utile", slug: "travail-utile", summary: "Résumé", body_markdown: "# Français" },
            "2" => { locale: "vi", title: "", slug: "", summary: "", body_markdown: "" }
          }
        } }
      end
    end

    project = Project.order(:id).last
    assert_redirected_to edit_admin_project_path(project)
    assert_equal %w[en fr], project.translations.order(:locale).pluck(:locale)
    assert_equal "useful-work", project.translations.find_by!(locale: "en").slug
    assert_equal [ @tag.id ], project.tag_ids
    assert project.cover_image.attached?
  end

  test "updates title without silently changing the slug" do
    project = create_project
    translation = project.translations.find_by!(locale: "en")
    patch admin_project_path(project), params: { project: {
      role: project.role,
      translations_attributes: { "0" => { id: translation.id, locale: "en", title: "New title", slug: translation.slug, summary: "Summary", body_markdown: "Body" } }
    } }
    assert_redirected_to edit_admin_project_path(project)
    assert_equal "existing-project", translation.reload.slug
  end

  test "does not let nested updates move a persisted translation to another locale" do
    project = create_project
    translation = project.translations.create!(
      locale: "fr", title: "Projet", slug: "projet", summary: "Résumé", body_markdown: "Corps"
    )
    patch admin_project_path(project), params: { project: {
      role: project.role,
      translations_attributes: { "0" => {
        id: translation.id, locale: "vi", title: "Projet", slug: "projet",
        summary: "Résumé", body_markdown: "Corps"
      } }
    } }
    assert_response :see_other
    assert_equal "fr", translation.reload.locale
  end

  test "renders entered translations and upload errors with 422" do
    post admin_projects_path, params: { project: {
      role: "Lead", cover_image: invalid_upload,
      translations_attributes: { "0" => { locale: "en", title: "Entered title", summary: "Entered summary", body_markdown: "Entered body" } }
    } }
    assert_response :unprocessable_entity
    assert_select "input[value='Entered title']"
    assert_select "[role='alert']", text: /cover image/i
  end

  test "purges the cover image through its nested resource" do
    project = create_project
    project.cover_image.attach(io: Rails.root.join("public/icon.png").open, filename: "cover.png", content_type: "image/png")
    attachment_id = project.cover_image.attachment.id

    delete admin_project_cover_image_path(project)

    assert_redirected_to edit_admin_project_path(project)
    refute ActiveStorage::Attachment.exists?(attachment_id)
  end

  test "purges only an owned gallery attachment" do
    project = create_project
    project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "owned.png", content_type: "image/png")
    owned_attachment = project.gallery_images.first
    other_project = create_project(slug: "other-project")
    other_project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "other.png", content_type: "image/png")
    other_attachment = other_project.gallery_images.first

    delete admin_project_gallery_image_path(project, other_attachment)
    assert_response :not_found
    assert ActiveStorage::Attachment.exists?(other_attachment.id)

    delete admin_project_gallery_image_path(project, owned_attachment)
    assert_redirected_to edit_admin_project_path(project)
    refute ActiveStorage::Attachment.exists?(owned_attachment.id)
  end

  test "renders destructive actions as standalone delete forms" do
    project = create_project
    project.cover_image.attach(io: Rails.root.join("public/icon.png").open, filename: "cover.png", content_type: "image/png")
    project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "gallery.png", content_type: "image/png")

    get admin_projects_path
    assert_delete_form admin_project_path(project)
    assert_select "a[data-turbo-method='delete']", count: 0

    get edit_admin_project_path(project)
    assert_delete_form admin_project_cover_image_path(project)
    assert_delete_form admin_project_gallery_image_path(project, project.gallery_images.first)
    assert_select "form form", count: 0
    assert_select "a[data-turbo-method='delete']", count: 0
  end

  test "appends gallery uploads without replacing existing images" do
    project = create_project
    project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "one.png", content_type: "image/png")

    patch admin_project_path(project), params: { project: {
      role: project.role,
      gallery_images: [ image_upload ]
    } }

    assert_response :see_other
    assert_equal %w[icon.png one.png], project.reload.gallery_images.map { |image| image.filename.to_s }.sort
  end

  test "rejects a malformed project scope" do
    post admin_projects_path, params: { project: "not-an-object" }
    assert_response :bad_request
  end

  test "destroys a project after confirmation is submitted" do
    project = create_project
    assert_difference("Project.count", -1) { delete admin_project_path(project) }
    assert_redirected_to admin_projects_path
  end

  private

  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
  end

  def invalid_upload
    Rack::Test::UploadedFile.new(Rails.root.join("Gemfile"), "text/plain")
  end

  def create_project(slug: "existing-project")
    Project.create!(role: "Engineer", translations_attributes: {
      "0" => { locale: "en", title: slug.humanize, slug:, summary: "Summary", body_markdown: "Body" }
    })
  end

  def assert_delete_form(path)
    assert_select "form[action='#{path}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
  end
end
