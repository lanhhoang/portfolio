# Phase 7 Release Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing public application release-ready for metadata consumers, expected error paths, responsive media, keyboard users, reduced-motion settings, all approved themes and accents, 320 CSS-pixel viewports, and real 200% browser zoom.

**Architecture:** Extend the existing Rails-rendered public surface without replacing working Phase 1–6 behavior. A metadata helper feeds the public layout, a top-level XML controller enumerates routable public URLs, an error controller renders localized failures through the public layout, and one helper renders analyzed Active Storage images with native `srcset` and `sizes`. Keep the existing menu controller, locale-switch paths, theme controller, CSS token names, and mobile-first layouts; add only missing regression coverage and concrete fixes exposed by it.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.3.1, ERB, Active Storage variants with libvips, Hotwire/Stimulus, Tailwind CSS 4, Minitest, Capybara, Selenium/Chrome

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

## Global Constraints

- Public locales are exactly `en`, `fr`, and `vi`; English authored content is required and other authored translations are optional.
- Public URLs use explicit locale prefixes; `/` redirects by locale cookie, supported `Accept-Language`, then `/en`.
- The admin interface is English and supports one owner only; there is no registration.
- Public and admin CSS is mobile-first; every action remains usable at 320 CSS pixels, real 200% browser zoom, and without hover.
- Initial color mode follows `prefers-color-scheme`; a manual override is stored under `portfolio-theme` in `localStorage` and applied before paint.
- Accent presets are fixed to Brown, Green, Lime, Orange, and Yellow; Lime is the default.
- Markdown raw HTML stays disabled and rendered output is sanitized before persistence and again at public render boundaries.
- Draft, scheduled, future-published, missing, and unpublished translations never leak through public routes, search, metadata, or sitemap.
- Contact messages commit before email delivery and remain retryable after delivery failure.
- Production remains one application container on one small Ubuntu server; do not add Redis, a separate API, SPA, CMS, search service, CDN, or observability platform.
- Use Rails defaults, existing dependencies, and the standard library. Do not add a gem, npm package, or import-map pin in this phase.
- Use Minitest and Capybara. Each behavior task follows red-green-refactor and ends with a focused test run and commit.

## Audited Baseline and Fixed Assumptions

This plan was reconciled with commit `90da104` on branch `20260906-portfolio-v4-phase-07-release-quality`.

The following commands passed before Phase 7 changes:

```text
bin/rails test         # 212 runs, 1115 assertions, 0 failures, 0 errors
bin/rails test:system  # 14 runs, 75 assertions, 0 failures, 0 errors
bin/rubocop            # 145 files inspected, no offenses
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/importmap audit
```

Current interfaces to preserve:

- Locale authority: `PublicController::SUPPORTED_LOCALES`.
- Public detail records: `@translation` in projects, posts, profiles, and résumés.
- Existing equivalent-page map: `@locale_switch_paths`; project/post controllers include only currently public siblings, and profile/résumé controllers include only existing translations.
- Existing route helpers: `localized_root_url`, `localized_projects_url`, `localized_project_url`, `localized_blog_url`, `localized_post_url`, `localized_about_url`, `localized_resume_url`, `localized_resume_download_url`, and `localized_contact_url`.
- Publication authority: `ProjectTranslation.publicly_visible(locale:)` and `PostTranslation.publicly_visible(locale:)`.
- Existing system sign-in helper: `sign_in_owner`.
- Existing image fixture: `public/icon.png` is a 512×512 PNG. There is no `test/fixtures/files/cover.png`.
- Existing public singleton views are `app/views/public/profiles/show.html.erb` and `app/views/public/resumes/show.html.erb`.
- Existing system files are `test/system/public_shell_test.rb` and `test/system/admin_manages_content_test.rb`; do not refer to nonexistent `theme_test.rb` or `admin_content_management_test.rb` files.
- Existing semantic CSS variables are `--background`, `--foreground`, `--muted`, `--surface`, `--border`, `--accent`, `--accent-foreground`, and `--focus`. Do not rename them to a second token family.
- The existing menu controller already updates `aria-expanded`, hides and shows the panel, closes on Escape, and returns focus. Preserve it.
- The existing stylesheet already supplies visible focus, 44px control heights, responsive media bounds, contained rich-text tables/code, and reduced-motion overrides. Extend it only where tests identify a missing contract.
- Automated 320px checks are regression guards. Real Chrome page zoom at 200% remains a mandatory manual review because CSS `zoom`, device scale factor, and CDP page scaling do not reproduce browser text reflow faithfully.

## File Map

| Path | Responsibility |
| --- | --- |
| `app/helpers/metadata_helper.rb` | Normalize metadata, canonical URLs, existing/public alternates, Open Graph locales, and JSON-LD. |
| `app/views/layouts/application.html.erb` | Emit metadata and nonce-bearing escaped JSON-LD in the public/error layout. |
| `app/views/public/**/*.html.erb` | Declare page metadata, retain exactly one focusable `#main-content`, and render responsive attachments. |
| `app/controllers/sitemap_controller.rb` | Build absolute static, singleton, and publicly visible content URLs. |
| `app/views/sitemap/show.xml.builder` | Emit a minimal sitemap document. |
| `app/controllers/errors_controller.rb` | Resolve a safe locale and render branded 404/422/500 responses without exception details. |
| `app/views/errors/show.html.erb` | Shared localized error body and recovery link. |
| `app/helpers/responsive_image_helper.rb` | Render analyzed Active Storage images with truthful width descriptors and a safe unanalyzed fallback. |
| `app/assets/tailwind/application.css` | Preserve existing tokens; complete horizontal touch targets and visible accent swatches. |
| `test/requests/*.rb`, `test/helpers/*.rb`, `test/system/*.rb` | Focused metadata, sitemap, error, responsive-media, keyboard, contrast, motion, and viewport regressions. |

---

### Task 1: Canonical Metadata, Published Alternates, Open Graph, and JSON-LD

**Files:**

- Create: `app/helpers/metadata_helper.rb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/public/home/show.html.erb`
- Modify: `app/views/public/projects/index.html.erb`
- Modify: `app/views/public/projects/show.html.erb`
- Modify: `app/views/public/posts/index.html.erb`
- Modify: `app/views/public/posts/show.html.erb`
- Modify: `app/views/public/profiles/show.html.erb`
- Modify: `app/views/public/resumes/show.html.erb`
- Modify: `app/views/public/contact_messages/new.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/fr.yml`
- Modify: `config/locales/vi.yml`
- Create: `test/requests/public_metadata_test.rb`

**Interfaces:**

- Consumes: `PublicController::SUPPORTED_LOCALES`, `@locale_switch_paths`, `@translation`, `request.path_parameters`, and existing route helpers.
- Produces: `page_metadata`, `page_metadata_values`, `current_page_canonical_url`, `alternate_locale_links`, `project_json_ld`, `post_json_ld`, and `person_json_ld`.

- [ ] **Step 1: Add the failing metadata request test**

Create `test/requests/public_metadata_test.rb`:

```ruby
require "test_helper"

class PublicMetadataTest < ActionDispatch::IntegrationTest
  setup do
    host! "portfolio.example"
    https!

    @project = Project.new(role: "Engineer")
    @english = @project.translations.build(
      locale: "en", title: "Fast systems", slug: "fast-systems",
      summary: "A concise case study", body_markdown: "Body",
      state: "published", published_at: Time.zone.parse("2026-08-01 12:00:00")
    )
    @project.save!
    @project.translations.create!(
      locale: "fr", title: "Systèmes rapides", slug: "systemes-rapides",
      summary: "Une étude de cas concise", body_markdown: "Corps",
      state: "published", published_at: Time.zone.parse("2026-08-02 12:00:00")
    )
    @project.translations.create!(
      locale: "vi", title: "Hệ thống nhanh", slug: "he-thong-nhanh",
      summary: "Bản nháp", body_markdown: "Nội dung", state: "draft"
    )
  end

  test "detail metadata is canonical and includes public alternates only" do
    get localized_project_path(locale: :en, slug: @english.slug)

    assert_response :success
    document = Nokogiri::HTML(response.body)
    assert_equal "Fast systems", document.at_css("title").text
    assert_equal "A concise case study", document.at_css('meta[name="description"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('link[rel="canonical"]')["href"]
    assert_equal({
      "en" => "https://portfolio.example/en/projects/fast-systems",
      "fr" => "https://portfolio.example/fr/projects/systemes-rapides"
    }, document.css('link[rel="alternate"][hreflang]').to_h { |node| [ node["hreflang"], node["href"] ] })
    assert_nil document.at_css('link[hreflang="vi"]')
    assert_nil document.at_css('link[hreflang="x-default"]')
    assert_equal "website", document.at_css('meta[property="og:type"]')["content"]
    assert_equal "en_US", document.at_css('meta[property="og:locale"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('meta[property="og:url"]')["content"]

    json_node = document.at_css('script[type="application/ld+json"]')
    assert json_node["nonce"].present?
    json_ld = JSON.parse(json_node.text)
    assert_equal "CreativeWork", json_ld.fetch("@type")
    assert_equal "Fast systems", json_ld.fetch("name")
    assert_equal "https://portfolio.example/en/projects/fast-systems", json_ld.fetch("url")
  end

  test "filtered index metadata omits query parameters" do
    get localized_projects_path(locale: :en), params: { q: "rails", tag: "systems" }

    document = Nokogiri::HTML(response.body)
    assert_equal "https://portfolio.example/en/projects",
      document.at_css('link[rel="canonical"]')["href"]
    assert_equal %w[en fr vi], document.css('link[rel="alternate"][hreflang]').map { |node| node["hreflang"] }
    assert document.css('link[rel="alternate"][hreflang]').none? { |node| node["href"].include?("?") }
  end
end
```

- [ ] **Step 2: Verify the new test fails for missing release metadata**

Run:

```bash
bin/rails test test/requests/public_metadata_test.rb
```

Expected: FAIL because canonical, alternate, Open Graph, and JSON-LD nodes are absent.

- [ ] **Step 3: Add one metadata helper that reuses existing locale-switch decisions**

Create `app/helpers/metadata_helper.rb`:

```ruby
module MetadataHelper
  OG_LOCALES = { "en" => "en_US", "fr" => "fr_FR", "vi" => "vi_VN" }.freeze

  def page_metadata(title:, description:, canonical_url: current_page_canonical_url,
                    alternates: alternate_locale_links, og_type: "website",
                    image_url: nil, json_ld: nil, robots: "index,follow")
    @page_metadata = {
      title: title.to_s.strip,
      description: strip_tags(description.to_s).squish.truncate(160),
      canonical_url: canonical_url,
      alternates: alternates,
      og_type: og_type,
      og_locale: OG_LOCALES.fetch(I18n.locale.to_s),
      image_url: image_url,
      json_ld: json_ld,
      robots: robots
    }
  end

  def page_metadata_values
    @page_metadata || page_metadata(
      title: t("seo.site_name"),
      description: t("seo.default_description")
    )
  end

  def current_page_canonical_url(overrides = {})
    url_for(request.path_parameters.merge(overrides).merge(only_path: false))
  end

  def alternate_locale_links
    PublicController::SUPPORTED_LOCALES.filter_map do |locale|
      path = if instance_variable_defined?(:@locale_switch_paths)
        @locale_switch_paths[locale]
      else
        url_for(request.path_parameters.merge(locale: locale, only_path: true))
      end
      { locale: locale, url: "#{request.base_url}#{path}" } if path
    end
  end

  def project_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "CreativeWork",
      "name" => translation.title,
      "description" => strip_tags(translation.summary.to_s).squish,
      "inLanguage" => translation.locale,
      "datePublished" => translation.published_at&.iso8601,
      "url" => current_page_canonical_url
    }.compact
  end

  def post_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => translation.title,
      "description" => strip_tags(translation.excerpt.to_s).squish,
      "inLanguage" => translation.locale,
      "datePublished" => translation.published_at&.iso8601,
      "url" => current_page_canonical_url
    }.compact
  end

  def person_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => translation.display_name,
      "description" => strip_tags(translation.introduction.to_s).squish,
      "url" => current_page_canonical_url
    }
  end
end
```

Do not query translation tables from this helper. The existing controllers already compute the correct public/existing equivalent-page map, so `@locale_switch_paths` remains the single detail-page authority.

- [ ] **Step 4: Render normalized metadata in the public layout**

In `app/views/layouts/application.html.erb`, replace the existing `<title>` with this block. Keep `theme_bootstrap_script` before the stylesheet and JavaScript tags.

```erb
<% metadata = page_metadata_values %>
<title><%= metadata.fetch(:title) %></title>
<meta name="description" content="<%= metadata.fetch(:description) %>">
<meta name="robots" content="<%= metadata.fetch(:robots) %>">
<link rel="canonical" href="<%= metadata.fetch(:canonical_url) %>">
<% metadata.fetch(:alternates).each do |alternate| %>
  <link rel="alternate" hreflang="<%= alternate.fetch(:locale) %>" href="<%= alternate.fetch(:url) %>">
<% end %>
<meta property="og:site_name" content="<%= t("seo.site_name") %>">
<meta property="og:title" content="<%= metadata.fetch(:title) %>">
<meta property="og:description" content="<%= metadata.fetch(:description) %>">
<meta property="og:type" content="<%= metadata.fetch(:og_type) %>">
<meta property="og:url" content="<%= metadata.fetch(:canonical_url) %>">
<meta property="og:locale" content="<%= metadata.fetch(:og_locale) %>">
<% metadata.fetch(:alternates).reject { |alternate| alternate[:locale] == I18n.locale.to_s }.each do |alternate| %>
  <meta property="og:locale:alternate" content="<%= MetadataHelper::OG_LOCALES.fetch(alternate.fetch(:locale)) %>">
<% end %>
<% if metadata[:image_url].present? %>
  <meta property="og:image" content="<%= metadata[:image_url] %>">
<% end %>
<% if metadata[:json_ld].present? %>
  <script type="application/ld+json" nonce="<%= content_security_policy_nonce %>"><%= raw(json_escape(metadata[:json_ld].to_json)) %></script>
<% end %>
```

- [ ] **Step 5: Declare page-specific metadata in the actual public templates**

Add the matching declaration before `<main>` in each file:

```erb
<%# app/views/public/home/show.html.erb %>
<% page_metadata(title: t("seo.home.title"), description: t("seo.home.description")) %>
```

```erb
<%# app/views/public/projects/index.html.erb %>
<% page_metadata(title: t("seo.projects.title"), description: t("seo.projects.description")) %>
```

```erb
<%# app/views/public/projects/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.summary,
  alternates: alternate_locale_links,
  image_url: (@translation.project.cover_image.attached? ? url_for(@translation.project.cover_image) : nil),
  json_ld: project_json_ld(@translation)
) %>
```

```erb
<%# app/views/public/posts/index.html.erb %>
<% page_metadata(title: t("seo.blog.title"), description: t("seo.blog.description")) %>
```

```erb
<%# app/views/public/posts/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.excerpt,
  alternates: alternate_locale_links,
  og_type: "article",
  image_url: (@translation.post.cover_image.attached? ? url_for(@translation.post.cover_image) : nil),
  json_ld: post_json_ld(@translation)
) %>
```

```erb
<%# app/views/public/profiles/show.html.erb %>
<% page_metadata(
  title: t("seo.about.title"),
  description: @translation.introduction,
  alternates: alternate_locale_links,
  image_url: (@profile.portrait.attached? ? url_for(@profile.portrait) : nil),
  json_ld: person_json_ld(@translation)
) %>
```

```erb
<%# app/views/public/resumes/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.description,
  alternates: alternate_locale_links
) %>
```

Replace the current `content_for :title` line in `app/views/public/contact_messages/new.html.erb` with:

```erb
<% page_metadata(title: t("seo.contact.title"), description: t("seo.contact.description")) %>
```

- [ ] **Step 6: Merge exact fixed-page SEO copy into each existing locale root**

Add under `en:` in `config/locales/en.yml`:

```yaml
seo:
  site_name: "Portfolio"
  default_description: "Independent software engineering, interface design, and technical writing."
  home:
    title: "Ideas. Interfaces. Impact."
    description: "Independent software engineering, interface design, and technical writing."
  projects:
    title: "Work"
    description: "Selected software engineering and interface design projects."
  blog:
    title: "Journal"
    description: "Notes on software engineering, product design, and building for the web."
  about:
    title: "About"
  contact:
    title: "Contact"
    description: "Get in touch about software engineering and product work."
```

Add under `fr:` in `config/locales/fr.yml`:

```yaml
seo:
  site_name: "Portfolio"
  default_description: "Ingénierie logicielle indépendante, design d’interfaces et écrits techniques."
  home:
    title: "Idées. Interfaces. Impact."
    description: "Ingénierie logicielle indépendante, design d’interfaces et écrits techniques."
  projects:
    title: "Réalisations"
    description: "Une sélection de projets d’ingénierie logicielle et de design d’interfaces."
  blog:
    title: "Journal"
    description: "Notes sur l’ingénierie logicielle, le design produit et la création web."
  about:
    title: "À propos"
  contact:
    title: "Contactez-moi"
    description: "Échangeons autour de l’ingénierie logicielle et des produits numériques."
```

Add under `vi:` in `config/locales/vi.yml`:

```yaml
seo:
  site_name: "Portfolio"
  default_description: "Kỹ thuật phần mềm độc lập, thiết kế giao diện và bài viết kỹ thuật."
  home:
    title: "Ý tưởng. Giao diện. Tác động."
    description: "Kỹ thuật phần mềm độc lập, thiết kế giao diện và bài viết kỹ thuật."
  projects:
    title: "Dự án"
    description: "Các dự án tiêu biểu về kỹ thuật phần mềm và thiết kế giao diện."
  blog:
    title: "Nhật ký"
    description: "Ghi chép về kỹ thuật phần mềm, thiết kế sản phẩm và phát triển web."
  about:
    title: "Giới thiệu"
  contact:
    title: "Liên hệ"
    description: "Trao đổi về kỹ thuật phần mềm và phát triển sản phẩm."
```

Do not create duplicate locale roots or duplicate `seo:` keys.

- [ ] **Step 7: Run focused metadata and existing public regressions**

Run:

```bash
bin/rails test test/requests/public_metadata_test.rb test/integration/public_content_test.rb test/integration/public_localization_test.rb test/integration/public_contact_messages_test.rb
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Expected: all tests pass and Brakeman reports no warning for JSON-LD output.

- [ ] **Step 8: Commit metadata as one reviewable unit**

```bash
git add app/helpers/metadata_helper.rb app/views/layouts/application.html.erb app/views/public config/locales test/requests/public_metadata_test.rb
git commit -m "feat: add localized public metadata"
```

---

### Task 2: Published-Only XML Sitemap

**Files:**

- Modify: `config/routes.rb`
- Create: `app/controllers/sitemap_controller.rb`
- Create: `app/views/sitemap/show.xml.builder`
- Create: `test/requests/sitemap_test.rb`

**Interfaces:**

- Consumes: public URL helpers, singleton translation existence, and the two `publicly_visible(locale:)` scopes.
- Produces: `GET /sitemap.xml` with one absolute `<loc>` for each routable public HTML page.

- [ ] **Step 1: Add a failing sitemap boundary test**

Create `test/requests/sitemap_test.rb`:

```ruby
require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  setup do
    host! "portfolio.example"
    https!

    profile = Profile.new(public_contact_email: "owner@example.test")
    profile.translations.build(
      locale: "en", display_name: "Owner", headline: "Headline",
      introduction: "Introduction", biography_markdown: "Biography",
      availability_label: "Available"
    )
    profile.save!

    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Visible", slug: "visible", summary: "Summary",
      body_markdown: "Body", state: "published", published_at: 1.day.ago
    )
    project.save!
    project.translations.create!(
      locale: "fr", title: "Brouillon", slug: "brouillon", summary: "Résumé",
      body_markdown: "Corps", state: "draft"
    )
    project.translations.create!(
      locale: "vi", title: "Đã lên lịch", slug: "da-len-lich", summary: "Tóm tắt",
      body_markdown: "Nội dung", state: "scheduled", scheduled_at: 1.day.from_now
    )

    post = Post.new
    post.translations.build(
      locale: "en", title: "Visible post", slug: "visible-post", excerpt: "Excerpt",
      body_markdown: "Body", state: "published", published_at: 1.hour.ago
    )
    post.save!

    future_post = Post.new
    future_post.translations.build(
      locale: "en", title: "Future post", slug: "future-post", excerpt: "Excerpt",
      body_markdown: "Body", state: "published", published_at: 1.day.from_now
    )
    future_post.save!
  end

  test "sitemap contains routable pages and currently public content only" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body) { |config| config.strict }
    document.remove_namespaces!
    locations = document.xpath("//url/loc").map(&:text)

    assert_includes locations, "https://portfolio.example/en"
    assert_includes locations, "https://portfolio.example/en/projects"
    assert_includes locations, "https://portfolio.example/en/projects/visible"
    assert_includes locations, "https://portfolio.example/en/blog/visible-post"
    assert_includes locations, "https://portfolio.example/en/about"
    assert_not_includes locations, "https://portfolio.example/fr/about"
    assert_not_includes locations, "https://portfolio.example/fr/projects/brouillon"
    assert_not_includes locations, "https://portfolio.example/vi/projects/da-len-lich"
    assert_not_includes locations, "https://portfolio.example/en/blog/future-post"
    assert_equal locations.uniq.sort, locations
    assert locations.all? { |location| location.start_with?("https://portfolio.example/") }
  end
end
```

- [ ] **Step 2: Confirm the route is absent**

Run:

```bash
bin/rails test test/requests/sitemap_test.rb
```

Expected: FAIL with no route matching `/sitemap.xml`.

- [ ] **Step 3: Add the unlocalized XML route and controller**

Add before the locale scope in `config/routes.rb`:

```ruby
get "/sitemap.xml", to: "sitemap#show", defaults: { format: :xml }
```

Create `app/controllers/sitemap_controller.rb`:

```ruby
class SitemapController < ApplicationController
  def show
    @urls = PublicController::SUPPORTED_LOCALES.flat_map do |locale|
      static_urls(locale) + singleton_urls(locale) + content_urls(locale)
    end.uniq.sort
  end

  private

  def static_urls(locale)
    [
      localized_root_url(locale: locale),
      localized_projects_url(locale: locale),
      localized_blog_url(locale: locale),
      localized_contact_url(locale: locale)
    ]
  end

  def singleton_urls(locale)
    urls = []
    urls << localized_about_url(locale: locale) if ProfileTranslation.exists?(locale: locale)
    urls << localized_resume_url(locale: locale) if ResumeTranslation.exists?(locale: locale)
    urls
  end

  def content_urls(locale)
    projects = ProjectTranslation.publicly_visible(locale: locale).pluck(:slug).map do |slug|
      localized_project_url(locale: locale, slug: slug)
    end
    posts = PostTranslation.publicly_visible(locale: locale).pluck(:slug).map do |slug|
      localized_post_url(locale: locale, slug: slug)
    end
    projects + posts
  end
end
```

Do not include résumé PDF downloads, query/filter URLs, admin routes, root preference redirects, missing singleton translations, or records selected by raw state checks.

- [ ] **Step 4: Render a minimal escaped XML sitemap**

Create `app/views/sitemap/show.xml.builder`:

```ruby
xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @urls.each do |url|
    xml.url { xml.loc url }
  end
end
```

- [ ] **Step 5: Verify XML, publication boundaries, and route order**

Run:

```bash
bin/rails test test/requests/sitemap_test.rb test/integration/public_content_test.rb
bin/rails routes -g sitemap
```

Expected: tests pass and exactly one `GET /sitemap.xml(.:format)` route appears outside the locale scope.

- [ ] **Step 6: Commit the sitemap**

```bash
git add config/routes.rb app/controllers/sitemap_controller.rb app/views/sitemap/show.xml.builder test/requests/sitemap_test.rb
git commit -m "feat: add published content sitemap"
```

---

### Task 3: Safe Branded Localized Error Pages

**Files:**

- Modify: `config/application.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/errors_controller.rb`
- Create: `app/views/errors/show.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/fr.yml`
- Modify: `config/locales/vi.yml`
- Create: `test/requests/errors_test.rb`

**Interfaces:**

- Consumes: `action_dispatch.original_path`, locale cookie `portfolio_locale`, supported browser-language negotiation, the public layout, and Task 1 metadata.
- Produces: localized HTML 404, 422, and 500 responses with `noindex,nofollow`, safe home links, and no exception details.

- [ ] **Step 1: Add failing error request tests**

Create `test/requests/errors_test.rb`:

```ruby
require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  test "an unknown French URL receives a branded French 404" do
    with_public_exceptions do
      get "/fr/this-page-does-not-exist"
    end

    assert_response :not_found
    assert_includes response.body, "Page introuvable"
    assert_includes response.body, "Retour à l’accueil"
    assert_includes response.body, 'name="robots" content="noindex,nofollow"'
    assert_not_includes response.body, "ActionController::RoutingError"
  end

  test "direct 422 honors a supported browser locale and quality values" do
    get "/422", headers: { "Accept-Language" => "fr;q=0,vi-VN;q=0.9,en;q=0.5" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Không thể xử lý yêu cầu"
    assert_includes response.body, 'lang="vi"'
  end

  test "500 never renders exception details" do
    get "/500", headers: { "Accept-Language" => "en" }

    assert_response :internal_server_error
    assert_includes response.body, "Something went wrong"
    assert_not_includes response.body, "RuntimeError"
    assert_not_includes response.body, "backtrace"
  end

  private

  def with_public_exceptions
    previous = Rails.application.env_config["action_dispatch.show_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    yield
  ensure
    Rails.application.env_config["action_dispatch.show_exceptions"] = previous
  end
end
```

- [ ] **Step 2: Confirm branded routes and responses do not exist**

Run:

```bash
bin/rails test test/requests/errors_test.rb
```

Expected: FAIL because Rails is still using static error responses and `/422` and `/500` have no application routes.

- [ ] **Step 3: Route exceptions and fixed status paths**

Inside `Portfolio::Application` in `config/application.rb`, add:

```ruby
config.exceptions_app = routes
```

Near the end of `config/routes.rb`, after real application routes, add:

```ruby
match "/:code", to: "errors#show", via: :all,
  constraints: { code: /404|422|500/ }
```

Do not add a general catch-all route. Routing, controller, and server exceptions must all continue through `config.exceptions_app`.

- [ ] **Step 4: Add a locale-safe error controller that satisfies the public layout contract**

Create `app/controllers/errors_controller.rb`:

```ruby
class ErrorsController < ApplicationController
  layout "application"
  helper_method :current_locale

  def show
    @current_locale = error_locale
    @locale_switch_paths = PublicController::SUPPORTED_LOCALES.index_with do |locale|
      localized_root_path(locale: locale)
    end

    I18n.with_locale(@current_locale) do
      render :show, status: params.fetch(:code).to_i, formats: :html,
        locals: { code: params.fetch(:code).to_i }
    end
  end

  def current_locale
    @current_locale
  end

  private

  def error_locale
    original_path = request.get_header("action_dispatch.original_path").to_s
    path_locale = original_path.split("/").second
    return path_locale if path_locale.in?(PublicController::SUPPORTED_LOCALES)

    cookie_locale = cookies[:portfolio_locale].to_s
    return cookie_locale if cookie_locale.in?(PublicController::SUPPORTED_LOCALES)

    requested_locale || I18n.default_locale.to_s
  end

  def requested_locale
    request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
      .split(",")
      .each_with_index
      .filter_map do |entry, index|
        language_range, *parameters = entry.strip.split(";")
        locale = language_range.downcase.split("-").first
        next unless locale.in?(PublicController::SUPPORTED_LOCALES)

        quality_parameter = parameters.find { |parameter| parameter.strip.start_with?("q=") }
        quality = quality_parameter ? Float(quality_parameter.split("=", 2).last, exception: false).to_f : 1.0
        next unless quality.positive? && quality <= 1.0

        [ locale, quality, index ]
      end
      .max_by { |_locale, quality, index| [ quality, -index ] }
      &.first
  end
end
```

`current_locale` is required because the public layout and shared header normally receive it from `PublicController`. The explicit home-only `@locale_switch_paths` prevents the error layout from generating malformed locale variants of `/404`, `/422`, or `/500`.

- [ ] **Step 5: Add the shared localized error view**

Create `app/views/errors/show.html.erb`:

```erb
<% original_path = request.get_header("action_dispatch.original_path").presence || request.path %>
<% page_metadata(
  title: t("errors.pages.#{code}.title"),
  description: t("errors.pages.#{code}.message"),
  canonical_url: "#{request.base_url}#{original_path}",
  alternates: [],
  robots: "noindex,nofollow"
) %>

<main id="main-content" class="site-container page-shell" tabindex="-1">
  <p class="eyebrow" aria-hidden="true"><%= code %></p>
  <h1><%= t("errors.pages.#{code}.title") %></h1>
  <p class="prose-lead"><%= t("errors.pages.#{code}.message") %></p>
  <%= link_to t("errors.pages.home"), localized_root_path(locale: current_locale), class: "admin-action" %>
</main>
```

Keep page-level errors under `errors.pages` so they do not collide with the existing Rails validation keys under `errors.messages`.

- [ ] **Step 6: Merge complete error-page copy into all locale files**

Add under the existing `errors:` mapping in `config/locales/en.yml`:

```yaml
pages:
  home: "Back to home"
  "404":
    title: "Page not found"
    message: "The page may have moved, or it may not be available in this language."
  "422":
    title: "Request could not be processed"
    message: "Please review the request and try again."
  "500":
    title: "Something went wrong"
    message: "The request could not be completed. Please try again later."
```

Add under the existing `errors:` mapping in `config/locales/fr.yml`:

```yaml
pages:
  home: "Retour à l’accueil"
  "404":
    title: "Page introuvable"
    message: "Cette page a peut-être été déplacée ou n’est pas disponible dans cette langue."
  "422":
    title: "Impossible de traiter la demande"
    message: "Vérifiez la demande, puis réessayez."
  "500":
    title: "Une erreur est survenue"
    message: "La demande n’a pas pu aboutir. Réessayez plus tard."
```

Add under the existing `errors:` mapping in `config/locales/vi.yml`:

```yaml
pages:
  home: "Về trang chủ"
  "404":
    title: "Không tìm thấy trang"
    message: "Trang có thể đã được chuyển hoặc chưa có trong ngôn ngữ này."
  "422":
    title: "Không thể xử lý yêu cầu"
    message: "Vui lòng kiểm tra yêu cầu rồi thử lại."
  "500":
    title: "Đã xảy ra lỗi"
    message: "Không thể hoàn tất yêu cầu. Vui lòng thử lại sau."
```

- [ ] **Step 7: Run error, localization, route, and security regressions**

Run:

```bash
bin/rails test test/requests/errors_test.rb test/integration/public_localization_test.rb test/requests/admin/security_headers_test.rb
bin/rails routes -g errors
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Expected: tests pass, only 404/422/500 map to `ErrorsController`, and Brakeman reports no exception disclosure warning.

- [ ] **Step 8: Commit localized errors**

```bash
git add config/application.rb config/routes.rb app/controllers/errors_controller.rb app/views/errors/show.html.erb config/locales test/requests/errors_test.rb
git commit -m "feat: add localized public error pages"
```

---

### Task 4: Truthful Native Responsive Images

**Files:**

- Create: `app/helpers/responsive_image_helper.rb`
- Modify: `app/views/public/home/show.html.erb`
- Modify: `app/views/public/projects/index.html.erb`
- Modify: `app/views/public/projects/show.html.erb`
- Modify: `app/views/public/posts/show.html.erb`
- Modify: `app/views/public/profiles/show.html.erb`
- Modify: `test/integration/public_content_test.rb`
- Create: `test/helpers/responsive_image_helper_test.rb`

**Interfaces:**

- Consumes: analyzed Active Storage attachment metadata and existing `image_processing`/`ruby-vips` dependencies.
- Produces: `responsive_image_tag(attachment, alt:, sizes:, widths:, loading:, **options) -> ActiveSupport::SafeBuffer`.

- [ ] **Step 1: Add helper tests for analyzed and not-yet-analyzed images**

Create `test/helpers/responsive_image_helper_test.rb`:

```ruby
require "test_helper"

class ResponsiveImageHelperTest < ActionView::TestCase
  test "renders truthful width descriptors and intrinsic dimensions" do
    attachment = attached_icon
    attachment.blob.update!(metadata: { "width" => 512, "height" => 512, "analyzed" => true })

    html = responsive_image_tag(
      attachment,
      alt: "Dashboard overview",
      sizes: "(min-width: 48rem) 50vw, 100vw",
      widths: [ 320, 640 ]
    )
    node = Nokogiri::HTML.fragment(html).at_css("img")

    assert_equal "Dashboard overview", node["alt"]
    assert_equal "512", node["width"]
    assert_equal "512", node["height"]
    assert_equal "lazy", node["loading"]
    assert_equal "async", node["decoding"]
    assert_equal "(min-width: 48rem) 50vw, 100vw", node["sizes"]
    assert_includes node["srcset"], "320w"
    assert_includes node["srcset"], "512w"
    assert_not_includes node["srcset"], "640w"
  end

  test "uses the original attachment while analysis metadata is pending" do
    attachment = attached_icon
    attachment.blob.update!(metadata: {})

    html = responsive_image_tag(attachment, alt: "Pending image", sizes: "100vw")
    node = Nokogiri::HTML.fragment(html).at_css("img")

    assert_equal "Pending image", node["alt"]
    assert_nil node["srcset"]
    assert_nil node["width"]
    assert_nil node["height"]
  end

  private

  def attached_icon
    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Image test", slug: "image-test",
      summary: "Summary", body_markdown: "Body", state: "draft"
    )
    project.save!
    project.cover_image.attach(
      io: Rails.root.join("public/icon.png").open,
      filename: "icon.png",
      content_type: "image/png"
    )
    project.cover_image
  end
end
```

- [ ] **Step 2: Confirm the helper is undefined**

Run:

```bash
bin/rails test test/helpers/responsive_image_helper_test.rb
```

Expected: ERROR with `undefined method responsive_image_tag`.

- [ ] **Step 3: Implement responsive variants without lying about source width**

Create `app/helpers/responsive_image_helper.rb`:

```ruby
module ResponsiveImageHelper
  DEFAULT_WIDTHS = [ 320, 640, 960, 1280 ].freeze

  def responsive_image_tag(attachment, alt:, sizes:, widths: DEFAULT_WIDTHS,
                           loading: "lazy", **options)
    raise ArgumentError, "attachment must be attached" unless attachment.attached?

    metadata = attachment.blob.metadata
    intrinsic_width = metadata["width"].to_i
    intrinsic_height = metadata["height"].to_i

    unless intrinsic_width.positive? && intrinsic_height.positive?
      return image_tag(
        attachment, alt: alt, sizes: sizes, loading: loading,
        decoding: "async", **options
      )
    end

    candidate_widths = (widths.map(&:to_i).select { |width| width.positive? && width <= intrinsic_width } +
      [ intrinsic_width ]).uniq.sort
    variants = candidate_widths.to_h do |width|
      [ width, attachment.variant(resize_to_limit: [ width, nil ]) ]
    end

    image_tag(
      variants.fetch(candidate_widths.last),
      alt: alt,
      srcset: variants.map { |width, variant| [ variant, "#{width}w" ] },
      sizes: sizes,
      loading: loading,
      decoding: "async",
      width: intrinsic_width,
      height: intrinsic_height,
      **options
    )
  end
end
```

The unanalyzed branch intentionally serves the original attachment without false width descriptors. Active Storage analysis runs through the existing job system; subsequent renders receive responsive candidates and intrinsic dimensions.

- [ ] **Step 4: Replace every existing public Active Storage image call**

Use these calls at the existing guarded image positions. Do not add a post-index image because that view currently has no image in its content design.

`app/views/public/home/show.html.erb`, profile portrait:

```erb
<%= responsive_image_tag(
  @profile.portrait,
  alt: @profile_translation.display_name,
  sizes: "(min-width: 64rem) 24rem, 100vw",
  widths: [320, 480, 640, 960],
  class: "max-w-full"
) %>
```

`app/views/public/home/show.html.erb`, selected-project card:

```erb
<%= responsive_image_tag(
  translation.project.cover_image,
  alt: translation.title,
  sizes: "(min-width: 80rem) 40rem, (min-width: 48rem) 50vw, 100vw",
  class: "max-w-full"
) %>
```

`app/views/public/projects/index.html.erb`, project card:

```erb
<%= responsive_image_tag(
  translation.project.cover_image,
  alt: translation.title,
  sizes: "(min-width: 80rem) 40rem, (min-width: 48rem) 50vw, 100vw",
  class: "max-w-full"
) %>
```

`app/views/public/projects/show.html.erb`, detail cover:

```erb
<%= responsive_image_tag(
  @translation.project.cover_image,
  alt: @translation.title,
  sizes: "(min-width: 80rem) 80rem, 100vw",
  widths: [640, 960, 1280, 1600],
  loading: "eager",
  fetchpriority: "high",
  class: "max-w-full"
) %>
```

`app/views/public/projects/show.html.erb`, each gallery image:

```erb
<%= responsive_image_tag(
  image,
  alt: t("public.projects.gallery_alt", title: @translation.title, number: index + 1),
  sizes: "(min-width: 48rem) 50vw, 100vw",
  class: "max-w-full"
) %>
```

`app/views/public/posts/show.html.erb`, detail cover:

```erb
<%= responsive_image_tag(
  @translation.post.cover_image,
  alt: @translation.title,
  sizes: "(min-width: 80rem) 80rem, 100vw",
  widths: [640, 960, 1280, 1600],
  loading: "eager",
  fetchpriority: "high",
  class: "max-w-full"
) %>
```

`app/views/public/profiles/show.html.erb`, portrait:

```erb
<%= responsive_image_tag(
  @profile.portrait,
  alt: @translation.display_name,
  sizes: "(min-width: 64rem) 24rem, 100vw",
  widths: [320, 480, 640, 960],
  loading: "eager",
  class: "max-w-full"
) %>
```

Retain every existing `attached?` guard and missing-image text-first fallback.

- [ ] **Step 5: Add one request-level wiring regression**

Append this test to `PublicContentRequestTest` in `test/integration/public_content_test.rb`:

```ruby
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
```

- [ ] **Step 6: Run media and public-content regressions**

Run:

```bash
bin/rails test test/helpers/responsive_image_helper_test.rb test/integration/public_content_test.rb
rg -n "image_tag" app/views/public
```

Expected: tests pass and `rg` returns no direct public `image_tag` call for a cover, gallery image, or portrait.

- [ ] **Step 7: Commit responsive media**

```bash
git add app/helpers/responsive_image_helper.rb app/views/public test/helpers/responsive_image_helper_test.rb test/integration/public_content_test.rb
git commit -m "feat: serve responsive public images"
```

---

### Task 5: Keyboard, Contrast, Motion, Touch, and Narrow-Viewport Regression Gate

**Files:**

- Modify: `app/views/public/home/show.html.erb`
- Modify: `app/views/public/projects/index.html.erb`
- Modify: `app/views/public/projects/show.html.erb`
- Modify: `app/views/public/posts/index.html.erb`
- Modify: `app/views/public/posts/show.html.erb`
- Modify: `app/views/public/profiles/show.html.erb`
- Modify: `app/views/public/resumes/show.html.erb`
- Modify: `app/views/public/contact_messages/new.html.erb`
- Modify: `app/assets/tailwind/application.css`
- Modify: `test/system/public_shell_test.rb`
- Create: `test/system/release_quality_test.rb`

**Interfaces:**

- Consumes: existing `menu_controller.js`, `theme_controller.js`, `portfolio-theme`, `sign_in_owner`, `--background`, `--foreground`, `--accent`, `--accent-foreground`, `--focus`, and fixed profile accents.
- Produces: exactly one focusable `#main-content` per public page, generated Tailwind classes that use the existing CSS variables, 44×44px primary mobile targets, and browser-level release regressions.

- [ ] **Step 1: Add a failing skip-link regression to the existing public shell suite**

Append to `test/system/public_shell_test.rb`:

```ruby
test "skip link focuses main content on every public template" do
  profile = Profile.new(public_contact_email: "owner@example.test")
  profile.translations.build(
    locale: "en", display_name: "Owner", headline: "Headline",
    introduction: "Introduction", biography_markdown: "Biography",
    availability_label: "Available"
  )
  profile.save!
  resume = Resume.new(updated_on: Date.current)
  resume.translations.build(locale: "en", title: "Résumé", description: "Description")
  resume.save!

  [
    localized_root_path(locale: :en),
    localized_projects_path(locale: :en),
    localized_blog_path(locale: :en),
    localized_about_path(locale: :en),
    localized_resume_path(locale: :en),
    localized_contact_path(locale: :en)
  ].each do |path|
    visit path
    find("body").send_keys(:tab)
    assert page.active_element.matches_selector?(".skip-link"), path
    page.active_element.send_keys(:enter)
    assert page.active_element.matches_selector?("#main-content"), path
  end
end
```

Run:

```bash
bin/rails test:system test/system/public_shell_test.rb
```

Expected: FAIL because existing public `<main>` elements are not focus targets and the contact template has no `main-content` ID.

- [ ] **Step 2: Make the existing public main landmarks focusable**

On the opening `<main>` in each listed public view, preserve existing classes and attributes while adding:

```erb
id="main-content" tabindex="-1"
```

`app/views/public/contact_messages/new.html.erb` must begin its main landmark as:

```erb
<main id="main-content" class="mx-auto w-full max-w-3xl px-4 py-12 sm:px-6" tabindex="-1" aria-labelledby="contact-title">
```

Do not alter `app/javascript/controllers/menu_controller.js`; its current Escape, focus-return, label, hidden-state, and `aria-expanded` behavior already passes `test/system/public_shell_test.rb`.

- [ ] **Step 3: Add the browser-level release suite**

Create `test/system/release_quality_test.rb`:

```ruby
require "application_system_test_case"

class ReleaseQualityTest < ApplicationSystemTestCase
  ACCENTS = %w[brown green lime orange yellow].freeze

  setup do
    @profile = Profile.new(public_contact_email: "owner@example.test")
    @profile.translations.build(
      locale: "en", display_name: "Owner", headline: "Ideas. Interfaces. Impact.",
      introduction: "Introduction", biography_markdown: "Biography",
      availability_label: "Available"
    )
    @profile.save!

    @resume = Resume.new(updated_on: Date.current)
    @resume.translations.build(locale: "en", title: "Résumé", description: "Description")
    @resume.save!

    @project = Project.new(role: "Engineer", featured_position: 1)
    @project.translations.build(
      locale: "en", title: "Project", slug: "project", summary: "Summary",
      body_markdown: "Body", state: "published", published_at: 2.days.ago
    )
    @project.save!

    @post = Post.new
    @post.translations.build(
      locale: "en", title: "Post", slug: "post", excerpt: "Excerpt",
      body_markdown: "Body", state: "published", published_at: 1.day.ago
    )
    @post.save!
  end

  test "saved theme and every accent pass WCAG AA token contrast" do
    visit localized_root_path(locale: :en)

    %w[light dark].each do |theme|
      ACCENTS.each do |accent|
        @profile.update!(accent: accent)
        page.execute_script("localStorage.setItem('portfolio-theme', arguments[0])", theme)
        visit localized_root_path(locale: :en)

        assert_equal theme, find("html", visible: :all)["data-theme"]
        assert_equal accent, find("html", visible: :all)["data-accent"]
        assert_operator contrast("--foreground", "--background"), :>=, 4.5,
          "#{theme}/#{accent} body text must pass WCAG AA"
        assert_operator contrast("--accent", "--background"), :>=, 4.5,
          "#{theme}/#{accent} accent text and focus must pass WCAG AA"
        assert_operator contrast("--accent-foreground", "--accent"), :>=, 4.5,
          "#{theme}/#{accent} filled controls must pass WCAG AA"
      end
    end
  end

  test "public and admin pages do not overflow at 320 CSS pixels" do
    page.current_window.resize_to(320, 900)

    public_paths.each do |path|
      visit path
      assert_no_horizontal_overflow(path)
    end

    sign_in_owner
    admin_paths.each do |path|
      visit path
      assert_no_horizontal_overflow(path)
    end
  end

  test "primary mobile navigation targets are at least 44 pixels square" do
    page.current_window.resize_to(320, 900)
    visit localized_root_path(locale: :en)
    find(".menu-button").click

    all(".menu-button, .theme-button, .primary-navigation a, .locale-switcher a", visible: :visible).each do |element|
      box = page.evaluate_script(<<~JAVASCRIPT, element)
        const rect = arguments[0].getBoundingClientRect();
        return { width: rect.width, height: rect.height };
      JAVASCRIPT
      assert_operator box.fetch("width"), :>=, 44, element.text
      assert_operator box.fetch("height"), :>=, 44, element.text
    end
  end

  test "reduced motion collapses authored transition duration" do
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ]
    )
    visit localized_root_path(locale: :en)
    page.execute_script(<<~JAVASCRIPT)
      const probe = document.createElement("div");
      probe.id = "motion-probe";
      probe.style.transition = "transform 1s";
      document.body.appendChild(probe);
    JAVASCRIPT

    duration = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#motion-probe')).transitionDuration)")
    assert_operator duration, :<=, 0.00001
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  private

  def public_paths
    [
      localized_root_path(locale: :en),
      localized_projects_path(locale: :en),
      localized_project_path(locale: :en, slug: "project"),
      localized_blog_path(locale: :en),
      localized_post_path(locale: :en, slug: "post"),
      localized_about_path(locale: :en),
      localized_resume_path(locale: :en),
      localized_contact_path(locale: :en)
    ]
  end

  def admin_paths
    [
      admin_root_path,
      admin_projects_path,
      edit_admin_project_path(@project),
      admin_posts_path,
      edit_admin_post_path(@post),
      admin_tags_path,
      edit_admin_profile_path,
      edit_admin_resume_path,
      admin_messages_path
    ]
  end

  def assert_no_horizontal_overflow(path)
    dimensions = page.evaluate_script(<<~JAVASCRIPT)
      ({
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth
      });
    JAVASCRIPT
    assert_operator dimensions.fetch("scrollWidth"), :<=, dimensions.fetch("clientWidth") + 1,
      "#{path} overflows at 320px: #{dimensions.inspect}"
  end

  def contrast(first_token, second_token)
    luminances = [ first_token, second_token ].map { |token| relative_luminance(resolved_color(token)) }
    lighter, darker = luminances.max, luminances.min
    (lighter + 0.05) / (darker + 0.05)
  end

  def resolved_color(token)
    page.evaluate_script(<<~JAVASCRIPT, token)
      const probe = document.createElement("span");
      probe.style.color = `var(${arguments[0]})`;
      document.body.appendChild(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    JAVASCRIPT
  end

  def relative_luminance(css_color)
    channels = css_color.scan(/[\d.]+/).first(3).map { |channel| channel.to_f / 255.0 }
    linear = channels.map do |channel|
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
  end
end
```

- [ ] **Step 4: Run the new suite and capture only real failures**

Run:

```bash
bin/rails test:system test/system/release_quality_test.rb test/system/public_shell_test.rb
```

Expected initial failures:

- Short mobile navigation labels can be narrower than 44px.
- The contact page’s `text-accent`, `bg-accent`, and `text-accent-foreground` classes are absent from the generated Tailwind build because this application exposes `--accent` variables rather than Tailwind `--color-accent` theme tokens.
- Accent swatches refer to undefined `--accent-brown`, `--accent-green`, `--accent-lime`, `--accent-orange`, and `--accent-yellow` variables.

If any page still overflows, identify the exact overflowing element in the assertion’s path before changing CSS. Do not hide page overflow globally or add JavaScript resize behavior.

- [ ] **Step 5: Complete existing tokens and generated classes without introducing a second theme system**

In the existing `:root` block in `app/assets/tailwind/application.css`, add the fixed admin swatch values:

```css
--accent-brown: #7a4e35;
--accent-green: #216e46;
--accent-lime: #5a7600;
--accent-orange: #a94300;
--accent-yellow: #806100;
```

In the existing `.primary-navigation a` rule, add:

```css
min-width: 2.75rem;
```

In the existing `.locale-switcher a, .locale-switcher span` rule, add:

```css
min-width: 2.75rem;
```

In `app/views/public/contact_messages/new.html.erb`, replace the ungenerated accent utility on the eyebrow:

```erb
<p class="text-sm font-semibold uppercase tracking-widest text-[var(--accent)]"><%= t("pages.contact.eyebrow") %></p>
```

Replace the ungenerated submit utilities with existing arbitrary-value variable utilities:

```erb
<%= form.submit t("contact.submit"), class: "min-h-12 cursor-pointer bg-[var(--accent)] px-6 py-3 font-semibold text-[var(--accent-foreground)]" %>
```

Keep all approved accent hex values and the current `--background`, `--foreground`, `--accent`, `--accent-foreground`, and `--focus` names unchanged.

- [ ] **Step 6: Run the complete focused browser regression group**

Run:

```bash
bin/rails test:system test/system/release_quality_test.rb test/system/public_shell_test.rb test/system/admin_manages_content_test.rb test/system/admin_publishing_test.rb test/system/contact_flow_test.rb
bin/rails test test/helpers/theme_helper_test.rb test/integration/public_content_test.rb test/integration/public_contact_messages_test.rb
```

Expected: all tests pass for ten theme/accent combinations, every listed public/admin page at 320px, reduced motion, existing menu behavior, skip-link focus, touch targets, admin content management, publishing, and contact flow.

- [ ] **Step 7: Commit the release interaction regressions and concrete fixes**

```bash
git add app/views/public app/assets/tailwind/application.css test/system/public_shell_test.rb test/system/release_quality_test.rb
git commit -m "test: enforce release presentation quality"
```

---

### Task 6: Full Review Gate, Manual Browser Matrix, and Release Tag

**Files:**

- Review only. Do not commit generated audit reports, screenshots, browser profiles, or dependency output.

**Interfaces:**

- Consumes: all Phase 1–7 behavior.
- Produces: a green automated gate, completed manual release review, clean working tree, and annotated `portfolio-v4-phase-07` tag.

- [ ] **Step 1: Check scope, dependencies, and generated assets**

Run:

```bash
git status --short
git diff --check
bundle check
bin/importmap json >/dev/null
git diff 90da104 -- Gemfile Gemfile.lock config/importmap.rb
```

Expected: working tree clean, no whitespace errors, dependencies satisfied, import map valid, and no dependency-file changes.

- [ ] **Step 2: Run the repository CI gate plus system tests**

Run:

```bash
bin/ci
bin/rails test:system
```

Expected: setup, RuboCop, Bundler Audit, import-map audit, Brakeman, Rails tests, test seed replant, and all system tests exit 0.

- [ ] **Step 3: Inspect metadata, sitemap, and errors over a real local HTTP server**

In terminal 1:

```bash
bin/rails db:seed
bin/rails server -b 127.0.0.1 -p 3000
```

In terminal 2:

```bash
curl -fsS http://127.0.0.1:3000/en | grep -E '<title>|rel="canonical"|hreflang|property="og:'
curl -fsS http://127.0.0.1:3000/en/projects/sample-system | grep -E 'application/ld\+json|CreativeWork|rel="canonical"|hreflang'
curl -fsS http://127.0.0.1:3000/sitemap.xml | ruby -rnokogiri -e 'Nokogiri::XML(STDIN.read) { |config| config.strict }; puts "valid XML"'
curl -fsS http://127.0.0.1:3000/sitemap.xml | grep -E '/(en|fr|vi)(/|<)'
curl -fsS -H 'Accept-Language: fr' http://127.0.0.1:3000/404 | grep -E 'Page introuvable|noindex,nofollow'
```

Expected: absolute query-free canonical URLs, only valid alternates, escaped valid JSON-LD, valid XML, supported locale prefixes only, and a French non-indexable error response. Create or retain one draft translation in admin and verify its slug appears in neither detail-page alternates nor sitemap output.

- [ ] **Step 4: Complete the responsive and real-zoom browser matrix**

Open Chrome DevTools, disable cache, and inspect these seven routes:

1. `/en`
2. one published project detail
3. one published post detail
4. `/en/contact`
5. `/admin/projects`
6. one admin project edit form
7. `/admin/messages`

Check every route at each viewport:

| Mode | CSS viewport |
| --- | --- |
| Phone portrait | 320 × 568 |
| Phone landscape | 568 × 320 |
| Tablet | 768 × 1024 |
| Laptop | 1280 × 800 |
| Desktop | 1440 × 900 |
| Large desktop | 1920 × 1080 |

At each width verify:

- no page-level horizontal scrollbar;
- source order matches visual and tab order;
- every action remains present and usable without hover;
- text does not collide, clip, or become an unreadably narrow fragment;
- code blocks and irreducible tables scroll only within their own container;
- images remain bounded and preserve layout space.

Then set Chrome page zoom to exactly **200%** at a 1280 × 800 browser window and repeat all seven routes. Pass only when content reflows without a page-level horizontal scrollbar.

- [ ] **Step 5: Complete keyboard, reduced-motion, theme, and accent review**

Using only `Tab`, `Shift+Tab`, `Enter`, `Space`, and `Escape`:

1. Traverse the skip link, site mark, mobile menu, five primary links, language switcher, theme toggle, contact form, and admin form actions.
2. Verify visible focus at every stop, correct `aria-expanded`, Escape close with focus return, and keyboard-operable destructive confirmations.
3. Enable macOS **System Settings → Accessibility → Display → Reduce motion**, reload, and verify menu/theme/Turbo feedback has no slide, zoom, or long fade.
4. Remove `portfolio-theme`, switch the operating system between light and dark, and verify initial mode follows the system without an incorrect-theme flash.
5. Save light, reload, save dark, and reload; verify each override persists.
6. In admin select Brown, Green, Lime, Orange, and Yellow. For each preset inspect a public page in light and dark and verify labels, links, focus rings, and filled controls remain readable.

- [ ] **Step 6: Inspect responsive image network behavior with representative media**

The development seed image is intentionally tiny and cannot demonstrate browser candidate selection. Through admin, upload a real cover image at least 1600px wide before this check.

In Chrome Network, filter to `Img`, disable cache, and reload the project index at 320px and 1440px. Verify:

- image elements expose `srcset`, `sizes`, `width`, and `height` after Active Storage analysis completes;
- the 320px card does not fetch the 1280px or 1600px candidate;
- below-fold card/gallery images are lazy;
- project/post detail heroes are eager and `fetchpriority="high"`;
- missing images retain the existing text-first fallback;
- the console and Rails log contain no variant-processing error.

- [ ] **Step 7: Review the phase diff and create the boundary tag**

Run:

```bash
git diff --stat 90da104..HEAD
git log --oneline 90da104..HEAD
git status --short
git tag -a portfolio-v4-phase-07 -m "Portfolio v4 phase 7: release quality"
git show --stat --oneline portfolio-v4-phase-07
```

Expected: only Phase 7 files changed, the working tree is clean, and the annotated tag points to the final Phase 7 commit. Do not edit the approved spec or the immutable parent plan to mark completion.

## Risks and Review Triggers

- **Metadata render order:** Rails renders the template before its layout, so template-level `page_metadata` assignments are available to the layout. Keep declarations before page markup for readability.
- **Alternate authority:** project/post alternates must continue using controller-built public sibling paths; profile/résumé alternates must continue using existing translations. Do not add duplicate translation queries to the metadata helper.
- **Canonical query leakage:** canonical and metadata alternate URLs derive only from `request.path_parameters`; search/tag query parameters must not appear.
- **JSON-LD injection:** retain `json_escape`, `raw`, and the CSP nonce together. Never place authored rendered HTML directly in JSON-LD.
- **Sitemap publication leakage:** only `publicly_visible(locale:)` is valid for projects and posts. A raw `state == "published"` check misses future timestamps.
- **Error recursion:** `ErrorsController` must satisfy the public layout without loading optional profile/résumé content and must never render exception objects or backtraces.
- **Responsive descriptors:** do not emit width descriptors before image dimensions are analyzed, and do not advertise candidates wider than the original image.
- **Variant cost:** four configured breakpoints plus the original intrinsic width are sufficient. Do not add a CDN, picture service, or eager pre-generation.
- **Existing behavior:** do not replace the menu controller, theme controller, locale-switch helper, or semantic token family while adding release tests.
- **Tailwind tokens:** use `bg-[var(--accent)]` and `text-[var(--accent)]`; `bg-accent` and `text-accent` are not generated by the current Tailwind theme.
- **Browser zoom:** CSS `zoom`, CDP page scale, and device pixel ratio do not prove WCAG reflow. Keep the manual real Chrome 200% check.
- **Contrast scope:** token contrast is necessary but component opacity and blended backgrounds still require manual inspection.

## Phase Acceptance

Phase 7 is complete only when:

- Every public page has a localized title and description, query-free canonical URL, Open Graph fields, and correct locale alternates.
- Project/post/profile structured data is valid JSON-LD, escaped, and nonce-bearing.
- Detail-page `hreflang` and sitemap output contain no draft, scheduled, future, missing, or unpublished translation URL.
- `/sitemap.xml` is valid XML and contains only routable public HTML pages.
- 404, 422, and 500 are branded and localized, emit `noindex,nofollow`, and disclose no exception details.
- Every existing public cover, gallery image, and portrait uses native Active Storage variants with truthful `srcset`, `sizes`, localized alt text, lazy loading except priority detail media, and intrinsic dimensions after analysis.
- Existing menu behavior, skip-link focus, visible focus, primary touch targets, reduced motion, saved theme, and all five owner accents pass focused browser tests.
- Public and admin flows pass automated 320 CSS-pixel checks and manual real 200% Chrome zoom without page-level horizontal overflow.
- `bin/ci` and `bin/rails test:system` exit 0.
- The manual browser and network matrix is complete, the tree is clean, and annotated tag `portfolio-v4-phase-07` exists.
