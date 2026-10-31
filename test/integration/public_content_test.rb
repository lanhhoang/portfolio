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
    assert_select "h1", text: "Demo Owner"
    assert_select ".hero-role", text: "Product engineer · English, French, Vietnamese"
    assert_select ".availability", text: "Available"
    assert_select "title", text: "Demo Owner · Product engineer"
    assert_select ".site-mark", text: "Demo Owner"
    assert_select "p", text: "Ideas. Interfaces. Impact."
    assert_select "a[href=?]", "/en/projects", text: "See the work"
    assert_select "a[href=?]", "/en/resume", text: "Read résumé"
    assert_select "h3", text: "Visible Project"
    assert_select "h3", text: "Visible Post"
    assert_select "img", count: 0
  end

  test "project index searches published active-locale content only" do
    get "/en/projects", params: { q: "SQLite" }

    assert_response :success
    assert_select "h2", text: "Visible Project"
    assert_select "h2", text: "Secret Draft", count: 0
  end

  test "project page leads with case study facts and links to the next case study" do
    @project.update!(started_on: Date.new(2024, 3, 1), live_url: "https://example.test")
    other = Project.new(role: "Lead")
    other.translations.build(
      locale: "en", title: "Older Project", slug: "older-project", summary: "Older",
      body_markdown: "Body", state: "published", published_at: 5.days.ago
    )
    other.save!

    get "/en/projects/visible-project"

    assert_select "dl.facts dt", text: "Role"
    assert_select "dl.facts dd", text: "Engineer"
    assert_select "dl.facts time[datetime='2024-03-01']", text: "2024"
    assert_select "dl.facts dd", text: /Present/
    assert_select "dl.facts a[href='https://example.test'][rel='noopener noreferrer']"
    assert_select ".page-end-nav a[href='/en/projects/older-project']", text: "Older Project"
    assert_select ".page-end-nav a[href='/en/projects']", text: "All work"
    assert_select ".page-end a[href='/en/contact']"

    get "/en/projects/older-project"
    assert_select ".page-end-nav a[href='/en/projects/visible-project']"
  end

  test "project page omits the next link when it is the only case study" do
    get "/en/projects/visible-project"

    assert_select ".page-end-nav a[href^='/en/projects/']", count: 0
    assert_select ".page-end-nav a[href='/en/projects']"
  end

  test "work rows show role and years before the summary" do
    @project.update!(started_on: Date.new(2021, 1, 1), ended_on: Date.new(2023, 6, 1))

    get "/en/projects"
    assert_select ".entry .entry-meta", text: /Engineer · 2021–2023/

    get "/en"
    assert_select "ul.entry-list li .entry-meta", text: /Engineer · 2021–2023/
  end

  test "post page links to older and newer articles and back to the index" do
    older = Post.new
    older.translations.build(
      locale: "en", title: "Older Post", slug: "older-post", excerpt: "Earlier",
      body_markdown: "Body", state: "published", published_at: 3.days.ago
    )
    older.save!

    get "/en/blog/visible-post"
    assert_select ".page-end-nav a[href='/en/blog/older-post']", text: "Older Post"
    assert_select ".page-end-nav", text: /Newer article/, count: 0
    assert_select ".page-end-nav a[href='/en/blog']", text: "All articles"

    get "/en/blog/older-post"
    assert_select ".page-end-nav a[href='/en/blog/visible-post']", text: "Visible Post"
  end

  test "footer lists the owner's social links" do
    @profile.update!(social_links: { "GitHub" => "https://github.com/demo" })

    get "/en"
    assert_select ".site-footer a[href='https://github.com/demo'][rel~=me]", text: "GitHub"
  end

  test "a search with no matches explains it and offers a way back" do
    get "/en/projects", params: { q: "nothing-matches-this" }

    assert_response :success
    assert_select "p", text: "No case studies match this search."
    assert_select "a[href=?]", "/en/projects", text: "Clear search and filters"
  end

  test "draft and absent locale detail routes return 404" do
    get "/en/projects/secret-draft"
    assert_response :not_found

    get "/fr/projects/visible-project"
    assert_response :not_found
  end

  test "tags link to their filtered index" do
    tag = Tag.new
    tag.translations.build(locale: "en", name: "Ruby", slug: "ruby")
    tag.save!
    @project.tags << tag
    @post.tags << tag

    get "/en/projects/visible-project"
    assert_select "dl.facts .tag-list a[href='/en/projects?tag=ruby']", text: "Ruby"

    get "/en/blog/visible-post"
    assert_select ".tag-list a[href='/en/blog?tag=ruby']", text: "Ruby"
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
    assert_select "a[href='/en/projects']", text: "See the work"
    assert_select "a[href='/en/contact']", text: "Send a message"

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

  test "public content renders analyzed attachments responsively" do
    @project.cover_image.attach(
      io: Rails.root.join("public/icon.png").open,
      filename: "icon.png",
      content_type: "image/png"
    )
    @project.cover_image.blob.update!(metadata: { "width" => 512, "height" => 512, "analyzed" => true })

    get localized_project_path(locale: :en, slug: "visible-project")

    assert_response :success
    assert_select 'img[srcset][sizes][width="512"][height="512"][loading="eager"][fetchpriority="high"]'
  end

  test "every public page has one focusable main landmark" do
    paths = [
      localized_root_path(locale: :en),
      localized_projects_path(locale: :en),
      localized_project_path(locale: :en, slug: "visible-project"),
      localized_blog_path(locale: :en),
      localized_post_path(locale: :en, slug: "visible-post"),
      localized_about_path(locale: :en),
      localized_resume_path(locale: :en),
      localized_contact_path(locale: :en)
    ]

    paths.each do |path|
      get path

      assert_response :success
      assert_select 'main#main-content[tabindex="-1"]', count: 1
    end
  end
end
