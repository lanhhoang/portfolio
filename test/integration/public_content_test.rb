# frozen_string_literal: true

require "test_helper"

class PublicContentRequestTest < ActionDispatch::IntegrationTest
  setup do
    @profile = Profile.new(public_contact_email: "owner@example.test", accent: "orange")
    @profile.translations.build(
      locale: "en", display_name: "Demo Owner", headline: "Ideas. Interfaces. Impact.",
      introduction: "A demonstration introduction.", biography_markdown: "## Biography",
      availability_label: "Available"
    )
    @profile.save!

    @resume = Resume.new(updated_on: Date.new(2026, 9, 2))
    @resume.translations.build(locale: "en", title: "Résumé", description: "Current résumé")
    @resume.save!

    @project = Project.new(role: "Engineer", featured_position: 1)
    @project.translations.build(
      locale: "en", title: "Visible Project", slug: "visible-project", summary: "SQLite search target",
      body_markdown: "Project body", state: "published", published_at: 2.days.ago
    )
    @project.save!

    @draft = Project.new(role: "Engineer")
    @draft.translations.build(
      locale: "en", title: "Secret Draft", slug: "secret-draft", summary: "Private",
      body_markdown: "Draft body", state: "draft"
    )
    @draft.save!

    @post = Post.new
    @post.translations.build(
      locale: "en", title: "Visible Post", slug: "visible-post", excerpt: "Published writing",
      body_markdown: "Post body", state: "published", published_at: 1.day.ago
    )
    @post.save!
  end

  test "homepage renders active-locale database content and persisted accent" do
    get "/en"

    assert_response :success
    assert_select 'html[data-accent="orange"]'
    assert_select "h1", text: "Ideas. Interfaces. Impact."
    assert_select "h2", text: "Visible Project"
    assert_select "h2", text: "Visible Post"
    assert_select "img", count: 0
  end

  test "project index searches published active-locale content only" do
    get "/en/projects", params: { q: "SQLite" }

    assert_response :success
    assert_select "h2", text: "Visible Project"
    assert_select "h2", text: "Secret Draft", count: 0
  end

  test "draft and absent locale detail routes return 404" do
    get "/en/projects/secret-draft"
    assert_response :not_found

    get "/fr/projects/visible-project"
    assert_response :not_found
  end

  test "post detail renders stored HTML" do
    get "/en/blog/visible-post"

    assert_response :success
    assert_select "article p", text: "Post body"
  end

  test "missing optional translations return 404 for about and resume" do
    get "/fr/about"
    assert_response :not_found

    get "/fr/resume"
    assert_response :not_found
  end

  test "resume page has a text fallback and download returns 404 without a PDF" do
    get "/en/resume"
    assert_response :success
    assert_select "p", text: I18n.t("public.resume.pdf_unavailable", locale: :en)

    get "/en/resume/download"
    assert_response :not_found
  end
end
