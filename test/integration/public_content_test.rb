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

  test "stored body HTML is sanitized again at render time" do
    @post.translations.first.update_columns(body_html: "<p>Safe</p><script>alert(1)</script>")

    get "/en/blog/visible-post"

    assert_response :success
    assert_select "article p", text: "Safe"
    assert_select "script", text: "alert(1)", count: 0
  end

  test "detail locale switches use published sibling slugs and disable unavailable translations" do
    @project.translations.create!(
      locale: "fr", title: "Projet visible", slug: "projet-visible", summary: "Résumé",
      body_markdown: "Corps", state: "published", published_at: 1.day.ago
    )
    @project.translations.create!(
      locale: "vi", title: "Dự án nháp", slug: "du-an-nhap", summary: "Tóm tắt",
      body_markdown: "Nội dung", state: "draft"
    )

    get "/en/projects/visible-project"

    assert_select '.locale-switcher a[href="/fr/projects/projet-visible"]', text: "Français"
    assert_select '.locale-switcher span[lang="vi"][aria-disabled="true"]', text: "Tiếng Việt"
    assert_select '.locale-switcher a[href="/vi/projects/visible-project"]', count: 0

    @post.translations.create!(
      locale: "fr", title: "Article visible", slug: "article-visible", excerpt: "Extrait",
      body_markdown: "Corps", state: "published", published_at: 1.day.ago
    )

    get "/en/blog/visible-post"

    assert_select '.locale-switcher a[href="/fr/blog/article-visible"]', text: "Français"
    assert_select '.locale-switcher span[lang="vi"][aria-disabled="true"]', text: "Tiếng Việt"
  end

  test "singleton locale switches link existing and disable missing translations" do
    @profile.translations.create!(
      locale: "fr", display_name: "Propriétaire démo", headline: "Titre",
      introduction: "Introduction", biography_markdown: "Biographie",
      availability_label: "Disponible"
    )
    @resume.translations.create!(locale: "fr", title: "CV", description: "CV actuel")

    get "/en/about"
    assert_select '.locale-switcher a[href="/fr/about"]', text: "Français"
    assert_select '.locale-switcher span[lang="vi"][aria-disabled="true"]', text: "Tiếng Việt"

    get "/en/resume"
    assert_select '.locale-switcher a[href="/fr/resume"]', text: "Français"
    assert_select '.locale-switcher span[lang="vi"][aria-disabled="true"]', text: "Tiếng Việt"
  end

  test "French and Vietnamese dates render without missing translations" do
    @resume.translations.create!(locale: "fr", title: "CV", description: "CV actuel")
    @resume.translations.create!(locale: "vi", title: "Hồ sơ", description: "Hồ sơ hiện tại")

    get "/fr/resume"
    assert_select "p", text: "Mis à jour le 2 septembre 2026"

    get "/vi/resume"
    assert_select "p", text: "Cập nhật 2 tháng 9, 2026"
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

  test "publication transitions expose only the selected locale" do
    french = @project.translations.create!(
      locale: "fr", title: "Projet", slug: "projet", summary: "Résumé",
      body_markdown: "Corps"
    )
    vietnamese = @project.translations.create!(
      locale: "vi", title: "Dự án", slug: "du-an", summary: "Tóm tắt",
      body_markdown: "Nội dung"
    )

    get "/fr/projects/#{french.slug}"
    assert_response :not_found

    french.publish
    get "/fr/projects/#{french.slug}"
    assert_response :success
    get "/vi/projects/#{vietnamese.slug}"
    assert_response :not_found

    due_at = 1.hour.from_now.change(usec: 0)
    vietnamese.schedule(at: due_at)
    travel_to due_at do
      PublishDueTranslationsJob.perform_now
      get "/vi/projects/#{vietnamese.slug}"
      assert_response :success
    end

    french.unpublish
    get "/fr/projects/#{french.slug}"
    assert_response :not_found
  end
end
