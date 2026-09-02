# Phase 7 Release Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the public application release-ready across supported locales, metadata consumers, expected error paths, responsive media, keyboards, reduced-motion settings, themes, accents, 320 CSS-pixel viewports, and 200% zoom.

**Architecture:** Keep release behavior in Rails-rendered helpers, views, and controllers: one metadata helper feeds the application layout, one XML endpoint enumerates public URLs, and one error controller renders safe localized failures. Reuse Active Storage variants, the existing Stimulus menu/theme controllers, and semantic CSS tokens; add no audit, SEO, image, or accessibility dependency.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, ERB, Active Storage variants, Hotwire/Stimulus, Tailwind CSS, Minitest, Capybara, Selenium/Chrome

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

## Global Constraints

- Public locales are exactly `en`, `fr`, and `vi`; English authored content is required and other translations are optional.
- Public URLs use explicit locale prefixes; `/` redirects by locale cookie, supported `Accept-Language`, then `/en`.
- The admin interface is English and supports one owner only; there is no registration.
- Public and admin CSS is mobile-first; every action remains usable at 320 CSS pixels, 200% zoom, and without hover.
- Initial color mode follows `prefers-color-scheme`; a manual override is stored in `localStorage` and applied before paint.
- Accent presets are fixed to Brown, Green, Lime, Orange, and Yellow; Lime is the default.
- Markdown raw HTML stays disabled and rendered output is sanitized before persistence.
- Draft, scheduled, missing, and unpublished translations never leak through public routes, search, metadata, or sitemap.
- Contact messages commit before email delivery and remain retryable after delivery failure.
- Production remains one application container on one small Ubuntu server; do not add Redis, a separate API, SPA, CMS, search service, CDN, or observability platform.
- Primary SQLite data and every Active Storage asset receive encrypted off-site backups with 7 daily, 4 weekly, and 6 monthly restore points.
- Use Rails defaults and the standard library before adding dependencies. Do not add a gem or npm package in this phase.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.

## Preconditions and Fixed Assumptions

- Phases 1–6 are complete and `bin/rails test && bin/rails test:system` is green before this phase starts.
- Phase 2 public project, post, about, and résumé detail actions expose the active locale record as `@translation`; their existing views use the same name.
- The Phase 2 scopes `ProjectTranslation.publicly_visible(locale:)` and `PostTranslation.publicly_visible(locale:)` are the sole authority for whether a content URL may appear publicly.
- Phase 2 public route helpers are `localized_root_url`, `localized_projects_url`, `localized_project_url`, `localized_blog_url`, `localized_post_url`, `localized_about_url`, `localized_resume_url`, `localized_resume_download_url`, and `localized_contact_url`; all accept `locale:`, and detail helpers also accept `slug:`.
- Phase 4 provides `test/fixtures/files/cover.png` and system authentication helper `sign_in_owner`. Reuse them.
- Metadata descriptions are plain text, trimmed to 160 characters, and canonical URLs never include search/filter query parameters.
- `hreflang` contains only `en`, `fr`, and `vi`; do not emit `x-default`, because `/` is a preference redirect rather than a canonical content page.
- The 320px and 200% automated checks are regression guards, not substitutes for the explicit browser review in Task 7.

## File Map

| Path                                                 | Responsibility                                                                                       |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `app/helpers/metadata_helper.rb`                     | Normalize page metadata, published alternates, Open Graph locales, and JSON-LD payloads.             |
| `app/views/layouts/application.html.erb`             | Emit title, description, canonical, robots, Open Graph, `hreflang`, and escaped JSON-LD.             |
| `app/views/public/**`                                | Declare page-specific metadata and use responsive image rendering.                                   |
| `app/helpers/responsive_image_helper.rb`             | Render one Active Storage attachment with native `srcset`/`sizes`.                                   |
| `app/controllers/sitemap_controller.rb`              | Collect only routable static pages and publicly visible translations.                                |
| `app/views/sitemap/show.xml.builder`                 | Render the standards-based sitemap.                                                                  |
| `app/controllers/errors_controller.rb`               | Resolve a safe locale and render branded 404/422/500 responses.                                      |
| `app/views/errors/show.html.erb`                     | Shared localized error presentation with recovery link.                                              |
| `config/routes.rb`, `config/application.rb`          | Expose sitemap and route production exceptions through Rails.                                        |
| `config/locales/{en,fr,vi}.yml`                      | Exact localized SEO and error copy.                                                                  |
| `app/javascript/controllers/menu_controller.js`      | Preserve menu ARIA state and return focus on Escape.                                                 |
| `app/assets/tailwind/application.css`                | Semantic theme/accent tokens, visible focus, touch targets, overflow protection, and reduced motion. |
| `test/requests/*`, `test/helpers/*`, `test/system/*` | Focused release regressions and end-to-end review automation.                                        |

---

### Task 1: Canonical Metadata, `hreflang`, Open Graph, and JSON-LD

**Files:**

- Create: `app/helpers/metadata_helper.rb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/public/home/show.html.erb`
- Modify: `app/views/public/projects/index.html.erb`
- Modify: `app/views/public/projects/show.html.erb`
- Modify: `app/views/public/posts/index.html.erb`
- Modify: `app/views/public/posts/show.html.erb`
- Modify: `app/views/public/about/show.html.erb`
- Modify: `app/views/public/resume/show.html.erb`
- Modify: `app/views/public/contact_messages/new.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/fr.yml`
- Modify: `config/locales/vi.yml`
- Create: `test/requests/public_metadata_test.rb`

**Interfaces:**

- Consumes: Phase 2 public translation scopes and the shared `@translation` detail-page instance variable named in Preconditions.
- Produces: `page_metadata(title:, description:, canonical_url:, alternates:, og_type:, image_url:, json_ld:, robots:) -> Hash`, `current_page_canonical_url -> String`, `alternate_locale_links(translation = nil) -> Array<Hash>`, `project_json_ld`, `post_json_ld`, and `person_json_ld`.

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
    @french = @project.translations.create!(
      locale: "fr", title: "Systèmes rapides", slug: "systemes-rapides",
      summary: "Une étude de cas concise", body_markdown: "Corps",
      state: "published", published_at: Time.zone.parse("2026-08-02 12:00:00")
    )
    @project.translations.create!(
      locale: "vi", title: "Hệ thống nhanh", slug: "he-thong-nhanh",
      summary: "Bản nháp", body_markdown: "Nội dung", state: "draft"
    )
  end

  test "detail metadata is canonical and includes published alternates only" do
    get "/en/projects/#{@english.slug}"

    assert_response :success
    document = Nokogiri::HTML(response.body)
    assert_equal "Fast systems", document.at_css("title").text
    assert_equal "A concise case study", document.at_css('meta[name="description"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('link[rel="canonical"]')["href"]
    assert_equal({
      "en" => "https://portfolio.example/en/projects/fast-systems",
      "fr" => "https://portfolio.example/fr/projects/systemes-rapides"
    }, document.css('link[rel="alternate"][hreflang]').to_h { |node| [node["hreflang"], node["href"]] })
    assert_nil document.at_css('link[hreflang="vi"]')
    assert_equal "website", document.at_css('meta[property="og:type"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('meta[property="og:url"]')["content"]

    json_ld = JSON.parse(document.at_css('script[type="application/ld+json"]').text)
    assert_equal "CreativeWork", json_ld.fetch("@type")
    assert_equal "Fast systems", json_ld.fetch("name")
    assert_equal "https://portfolio.example/en/projects/fast-systems", json_ld.fetch("url")
  end

  test "index canonical strips query parameters" do
    get "/en/projects?q=rails&tag=systems"

    document = Nokogiri::HTML(response.body)
    assert_equal "https://portfolio.example/en/projects",
      document.at_css('link[rel="canonical"]')["href"]
  end
end
```

- [ ] **Step 2: Run the test and verify the release metadata is absent**

Run:

```bash
bin/rails test test/requests/public_metadata_test.rb
```

Expected: FAIL because canonical, alternate, Open Graph, and JSON-LD elements do not all exist.

- [ ] **Step 3: Implement the metadata helper**

Create `app/helpers/metadata_helper.rb`:

```ruby
module MetadataHelper
  SUPPORTED_LOCALES = %w[en fr vi].freeze
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
      title: I18n.t("seo.site_name"),
      description: I18n.t("seo.default_description")
    )
  end

  def current_page_canonical_url(overrides = {})
    url_for(request.path_parameters.merge(overrides).merge(only_path: false))
  end

  def alternate_locale_links(translation = nil)
    records = translation ? translated_siblings(translation) : SUPPORTED_LOCALES.map { |locale| [locale, nil] }
    records.map do |locale, sibling|
      overrides = { locale: locale }
      overrides[:slug] = sibling.slug if sibling&.respond_to?(:slug)
      { locale: locale, url: current_page_canonical_url(overrides) }
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

  private

  def translated_siblings(translation)
    locales = SUPPORTED_LOCALES
    case translation
    when ProjectTranslation
      locales.filter_map do |locale|
        sibling = ProjectTranslation.publicly_visible(locale: locale).find_by(project_id: translation.project_id)
        [locale, sibling] if sibling
      end
    when PostTranslation
      locales.filter_map do |locale|
        sibling = PostTranslation.publicly_visible(locale: locale).find_by(post_id: translation.post_id)
        [locale, sibling] if sibling
      end
    when ProfileTranslation
      locales.filter_map do |locale|
        sibling = ProfileTranslation.find_by(profile_id: translation.profile_id, locale: locale)
        [locale, sibling] if sibling
      end
    when ResumeTranslation
      locales.filter_map do |locale|
        sibling = ResumeTranslation.find_by(resume_id: translation.resume_id, locale: locale)
        [locale, sibling] if sibling
      end
    else
      raise ArgumentError, "unsupported metadata translation: #{translation.class.name}"
    end
  end
end
```

- [ ] **Step 4: Render the normalized values in the application `<head>`**

In `app/views/layouts/application.html.erb`, replace hard-coded title/description tags with this block inside `<head>`; keep the Phase 1 pre-paint theme script before stylesheets:

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
  <script type="application/ld+json"><%= raw(json_escape(metadata[:json_ld].to_json)) %></script>
<% end %>
```

- [ ] **Step 5: Declare exact metadata in each public template**

Add the matching declaration as the first ERB statement in each template:

```erb
<%# app/views/public/home/show.html.erb %>
<% page_metadata(title: t("seo.home.title"), description: t("seo.home.description")) %>

<%# app/views/public/projects/index.html.erb %>
<% page_metadata(title: t("seo.projects.title"), description: t("seo.projects.description")) %>

<%# app/views/public/projects/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.summary,
  alternates: alternate_locale_links(@translation),
  image_url: (@translation.project.cover_image.attached? ? url_for(@translation.project.cover_image) : nil),
  json_ld: project_json_ld(@translation)
) %>

<%# app/views/public/posts/index.html.erb %>
<% page_metadata(title: t("seo.blog.title"), description: t("seo.blog.description")) %>

<%# app/views/public/posts/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.excerpt,
  alternates: alternate_locale_links(@translation),
  og_type: "article",
  image_url: (@translation.post.cover_image.attached? ? url_for(@translation.post.cover_image) : nil),
  json_ld: post_json_ld(@translation)
) %>

<%# app/views/public/about/show.html.erb %>
<% page_metadata(
  title: t("seo.about.title"),
  description: @translation.introduction,
  alternates: alternate_locale_links(@translation),
  json_ld: person_json_ld(@translation)
) %>

<%# app/views/public/resume/show.html.erb %>
<% page_metadata(
  title: @translation.title,
  description: @translation.description,
  alternates: alternate_locale_links(@translation)
) %>

<%# app/views/public/contact_messages/new.html.erb %>
<% page_metadata(title: t("seo.contact.title"), description: t("seo.contact.description")) %>
```

Do not add query terms, tag names, draft siblings, or unavailable profile/résumé translations to these declarations.

- [ ] **Step 6: Add exact localized fixed-page SEO copy**

Merge these keys into the existing locale roots without replacing existing translations:

```yaml
# config/locales/en.yml
en:
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

```yaml
# config/locales/fr.yml
fr:
  seo:
    site_name: "Portfolio"
    default_description: "Ingénierie logicielle indépendante, design d’interfaces et écrits techniques."
    home:
      title: "Idées. Interfaces. Impact."
      description: "Ingénierie logicielle indépendante, design d’interfaces et écrits techniques."
    projects:
      title: "Projets"
      description: "Une sélection de projets d’ingénierie logicielle et de design d’interfaces."
    blog:
      title: "Journal"
      description: "Notes sur l’ingénierie logicielle, le design produit et la création web."
    about:
      title: "À propos"
    contact:
      title: "Contact"
      description: "Échangeons autour de l’ingénierie logicielle et des produits numériques."
```

```yaml
# config/locales/vi.yml
vi:
  seo:
    site_name: "Hồ sơ năng lực"
    default_description: "Kỹ thuật phần mềm độc lập, thiết kế giao diện và bài viết kỹ thuật."
    home:
      title: "Ý tưởng. Giao diện. Tác động."
      description: "Kỹ thuật phần mềm độc lập, thiết kế giao diện và bài viết kỹ thuật."
    projects:
      title: "Dự án"
      description: "Các dự án tiêu biểu về kỹ thuật phần mềm và thiết kế giao diện."
    blog:
      title: "Bài viết"
      description: "Ghi chép về kỹ thuật phần mềm, thiết kế sản phẩm và phát triển web."
    about:
      title: "Giới thiệu"
    contact:
      title: "Liên hệ"
      description: "Trao đổi về kỹ thuật phần mềm và phát triển sản phẩm."
```

- [ ] **Step 7: Run focused and full request tests**

Run:

```bash
bin/rails test test/requests/public_metadata_test.rb test/requests/public_projects_test.rb test/requests/public_posts_test.rb
```

Expected: PASS; the Vietnamese draft has no alternate link and filtered indexes retain a query-free canonical.

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

- Consumes: `publicly_visible(locale:)`, localized profile/résumé records, and fixed public URL structure.
- Produces: `GET /sitemap.xml`, returning `application/xml` with one absolute `<loc>` per routable public page.

- [ ] **Step 1: Write the failing sitemap request test**

Create `test/requests/sitemap_test.rb`:

```ruby
require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  setup do
    host! "portfolio.example"
    https!
    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Visible", slug: "visible", summary: "Summary",
      body_markdown: "Body", state: "published", published_at: Time.current
    )
    project.save!
    project.translations.create!(
      locale: "fr", title: "Brouillon", slug: "brouillon", summary: "Résumé",
      body_markdown: "Corps", state: "draft"
    )
  end

  test "sitemap contains fixed and published URLs but no draft URL" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body)
    document.remove_namespaces!
    locations = document.xpath("//url/loc").map(&:text)
    assert_includes locations, "https://portfolio.example/en"
    assert_includes locations, "https://portfolio.example/en/projects"
    assert_includes locations, "https://portfolio.example/en/projects/visible"
    assert_not_includes locations, "https://portfolio.example/fr/projects/brouillon"
    assert_equal locations.uniq, locations
  end
end
```

- [ ] **Step 2: Run the test and confirm the route is missing**

Run: `bin/rails test test/requests/sitemap_test.rb`

Expected: FAIL with no route matching `/sitemap.xml`.

- [ ] **Step 3: Add the unlocalized route and controller**

Add before the locale scope in `config/routes.rb`:

```ruby
get "/sitemap.xml", to: "sitemap#show", defaults: { format: :xml }
```

Create `app/controllers/sitemap_controller.rb`:

```ruby
class SitemapController < ApplicationController
  STATIC_PATHS = ["", "projects", "blog", "contact"].freeze

  def show
    base = request.base_url
    @urls = MetadataHelper::SUPPORTED_LOCALES.flat_map do |locale|
      static_urls(base, locale) + optional_urls(base, locale) + content_urls(base, locale)
    end.uniq.sort
  end

  private

  def static_urls(base, locale)
    STATIC_PATHS.map { |path| [base, locale, path].reject(&:blank?).join("/") }
  end

  def optional_urls(base, locale)
    urls = []
    urls << "#{base}/#{locale}/about" if ProfileTranslation.exists?(locale: locale)
    urls << "#{base}/#{locale}/resume" if ResumeTranslation.exists?(locale: locale)
    urls
  end

  def content_urls(base, locale)
    projects = ProjectTranslation.publicly_visible(locale: locale)
      .pluck(:slug).map { |slug| "#{base}/#{locale}/projects/#{ERB::Util.url_encode(slug)}" }
    posts = PostTranslation.publicly_visible(locale: locale)
      .pluck(:slug).map { |slug| "#{base}/#{locale}/blog/#{ERB::Util.url_encode(slug)}" }
    projects + posts
  end
end
```

- [ ] **Step 4: Render a minimal XML sitemap**

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
bin/rails test test/requests/sitemap_test.rb
bin/rails routes -g sitemap
```

Expected: PASS and exactly one `GET /sitemap.xml(.:format)` route outside the locale scope.

- [ ] **Step 6: Commit the sitemap**

```bash
git add config/routes.rb app/controllers/sitemap_controller.rb app/views/sitemap test/requests/sitemap_test.rb
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

- Consumes: the existing public layout and locale cookie named by Phase 1.
- Produces: localized HTML responses for 404, 422, and 500 with `noindex,nofollow` and no exception details.

- [ ] **Step 1: Write failing request tests for locale, status, and secrecy**

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
  end

  test "direct 422 uses the supported browser locale" do
    get "/422", headers: { "Accept-Language" => "vi-VN,vi;q=0.9,en;q=0.5" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Không thể xử lý yêu cầu"
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

- [ ] **Step 2: Run the tests and verify Rails does not yet render these pages**

Run: `bin/rails test test/requests/errors_test.rb`

Expected: FAIL because the localized error controller, routes, and copy do not exist.

- [ ] **Step 3: Route exceptions and direct status paths**

Inside `class Application < Rails::Application` in `config/application.rb`, add:

```ruby
config.exceptions_app = routes
```

Add near the end of `config/routes.rb`, after real application routes but before any existing catch-all:

```ruby
match "/:code", to: "errors#show", via: :all,
  constraints: { code: /404|422|500/ }
```

Do not add a general catch-all: `config.exceptions_app` must remain the common path for routing, controller, and server errors.

- [ ] **Step 4: Implement locale resolution from the failed original path**

Create `app/controllers/errors_controller.rb`:

```ruby
class ErrorsController < ApplicationController
  layout "application"

  def show
    status = params.fetch(:code).to_i
    I18n.with_locale(error_locale) do
      render :show, status: status, formats: :html,
        locals: { code: status, home_path: "/#{I18n.locale}" }
    end
  end

  private

  def error_locale
    original_path = request.get_header("action_dispatch.original_path").to_s
    path_locale = original_path.split("/").second
    return path_locale if MetadataHelper::SUPPORTED_LOCALES.include?(path_locale)

    cookie_locale = cookies[:portfolio_locale].to_s
    return cookie_locale if MetadataHelper::SUPPORTED_LOCALES.include?(cookie_locale)

    accepted = request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
      .scan(/[a-zA-Z]{2}/).map(&:downcase)
      .find { |locale| MetadataHelper::SUPPORTED_LOCALES.include?(locale) }
    accepted || "en"
  end
end
```

- [ ] **Step 5: Create the single status-aware error template**

Create `app/views/errors/show.html.erb`:

```erb
<% page_metadata(
  title: t("errors.#{code}.title"),
  description: t("errors.#{code}.message"),
  canonical_url: request.original_url.split("?").first,
  alternates: [],
  robots: "noindex,nofollow"
) %>

<main id="main-content" class="error-page content-container" tabindex="-1">
  <p class="eyebrow" aria-hidden="true"><%= code %></p>
  <h1><%= t("errors.#{code}.title") %></h1>
  <p><%= t("errors.#{code}.message") %></p>
  <%= link_to t("errors.home"), home_path, class: "button" %>
</main>
```

- [ ] **Step 6: Add complete error copy in all locales**

Merge these mappings under each locale root:

```yaml
# en.yml
en:
  errors:
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

```yaml
# fr.yml
fr:
  errors:
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

```yaml
# vi.yml
vi:
  errors:
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

If the locale files already start with `en:`, `fr:`, or `vi:`, merge only the nested `errors:` mapping; never create a second root key.

- [ ] **Step 7: Run error and route regressions**

Run:

```bash
bin/rails test test/requests/errors_test.rb test/integration/public_localization_test.rb
```

Expected: PASS; unsupported locale handling remains 404 and no error response includes exception text.

- [ ] **Step 8: Commit localized errors**

```bash
git add config/application.rb config/routes.rb app/controllers/errors_controller.rb app/views/errors config/locales test/requests/errors_test.rb
git commit -m "feat: add localized public error pages"
```

---

### Task 4: Native Responsive Images

**Files:**

- Create: `app/helpers/responsive_image_helper.rb`
- Modify: `app/views/public/home/show.html.erb`
- Modify: `app/views/public/projects/index.html.erb`
- Modify: `app/views/public/projects/show.html.erb`
- Modify: `app/views/public/posts/index.html.erb`
- Modify: `app/views/public/posts/show.html.erb`
- Modify: `app/views/public/about/show.html.erb`
- Create: `test/helpers/responsive_image_helper_test.rb`

**Interfaces:**

- Consumes: Phase 2/4 Active Storage attachments and image validation fixture.
- Produces: `responsive_image_tag(attachment, alt:, sizes:, widths:, loading:, **options) -> ActiveSupport::SafeBuffer`.

- [ ] **Step 1: Write the failing helper test**

Create `test/helpers/responsive_image_helper_test.rb`:

```ruby
require "test_helper"

class ResponsiveImageHelperTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  test "renders alt, intrinsic dimensions, srcset, sizes, and lazy decoding" do
    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Image test", slug: "image-test", summary: "Summary",
      body_markdown: "Body", state: "draft"
    )
    project.save!
    project.cover_image.attach(
      io: file_fixture("cover.png").open,
      filename: "cover.png",
      content_type: "image/png"
    )
    project.cover_image.blob.update!(metadata: { width: 1600, height: 900, analyzed: true })

    html = responsive_image_tag(
      project.cover_image,
      alt: "Dashboard overview",
      sizes: "(min-width: 64rem) 50vw, 100vw"
    )
    node = Nokogiri::HTML.fragment(html).at_css("img")

    assert_equal "Dashboard overview", node["alt"]
    assert_equal "1600", node["width"]
    assert_equal "900", node["height"]
    assert_equal "lazy", node["loading"]
    assert_equal "async", node["decoding"]
    assert_equal "(min-width: 64rem) 50vw, 100vw", node["sizes"]
    assert_includes node["srcset"], "320w"
    assert_includes node["srcset"], "1280w"
  end
end
```

- [ ] **Step 2: Run the test and confirm the helper is undefined**

Run: `bin/rails test test/helpers/responsive_image_helper_test.rb`

Expected: ERROR with `undefined method responsive_image_tag`.

- [ ] **Step 3: Implement one Active Storage helper without another image library**

Create `app/helpers/responsive_image_helper.rb`:

```ruby
module ResponsiveImageHelper
  DEFAULT_WIDTHS = [320, 640, 960, 1280].freeze

  def responsive_image_tag(attachment, alt:, sizes:, widths: DEFAULT_WIDTHS,
                           loading: "lazy", **options)
    raise ArgumentError, "attachment must be attached" unless attachment.attached?

    variants = widths.to_h do |width|
      [width, attachment.variant(resize_to_limit: [width, nil])]
    end
    metadata = attachment.blob.metadata

    image_tag(
      variants.fetch(widths.last),
      alt: alt,
      srcset: variants.map { |width, variant| "#{url_for(variant)} #{width}w" }.join(", "),
      sizes: sizes,
      loading: loading,
      decoding: "async",
      width: metadata["width"] || metadata[:width],
      height: metadata["height"] || metadata[:height],
      **options
    )
  end
end
```

- [ ] **Step 4: Replace public full-size attachment tags with explicit responsive calls**

Use these exact calls at the existing image positions; retain each existing `attached?` branch and text-first fallback:

```erb
<%# home selected-project card and projects index card, inside the existing `translation` loop %>
<%= responsive_image_tag(
  translation.project.cover_image,
  alt: translation.title,
  sizes: "(min-width: 80rem) 33vw, (min-width: 48rem) 50vw, 100vw",
  class: "content-image"
) %>

<%# project detail hero %>
<%= responsive_image_tag(
  @translation.project.cover_image,
  alt: @translation.title,
  sizes: "(min-width: 80rem) 72rem, 100vw",
  widths: [640, 960, 1280, 1600],
  loading: "eager",
  fetchpriority: "high",
  class: "content-image"
) %>

<%# blog index card, inside the existing `translation` loop %>
<%= responsive_image_tag(
  translation.post.cover_image,
  alt: translation.title,
  sizes: "(min-width: 64rem) 33vw, 100vw",
  class: "content-image"
) %>

<%# blog detail hero %>
<%= responsive_image_tag(
  @translation.post.cover_image,
  alt: @translation.title,
  sizes: "(min-width: 80rem) 72rem, 100vw",
  widths: [640, 960, 1280, 1600],
  loading: "eager",
  fetchpriority: "high",
  class: "content-image"
) %>

<%# about portrait %>
<%= responsive_image_tag(
  @profile.portrait,
  alt: @translation.display_name,
  sizes: "(min-width: 64rem) 24rem, 80vw",
  widths: [320, 480, 640, 960],
  class: "portrait-image"
) %>
```

There must be no remaining direct `image_tag` call for a public Active Storage cover or portrait. Decorative images, if any, use `alt: ""`; authored covers and portraits use the localized visible name shown above.

- [ ] **Step 5: Run helper, view, and attachment regressions**

Run:

```bash
bin/rails test test/helpers/responsive_image_helper_test.rb test/requests/public_content_test.rb
```

Expected: PASS; missing-image records still render their existing text fallback.

- [ ] **Step 6: Commit responsive media**

```bash
git add app/helpers/responsive_image_helper.rb app/views/public test/helpers/responsive_image_helper_test.rb
git commit -m "feat: serve responsive public images"
```

---

### Task 5: Keyboard Menu, Visible Focus, Touch Targets, and Reduced Motion

**Files:**

- Modify: `app/javascript/controllers/menu_controller.js`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/assets/tailwind/application.css`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/fr.yml`
- Modify: `config/locales/vi.yml`
- Create: `test/system/accessibility_navigation_test.rb`

**Interfaces:**

- Consumes: Phase 1 menu button/panel and native button-based theme control.
- Produces: `menu#toggle`, `menu#close`, `menu#escape`, stable selectors `[data-menu-target="button"]`, `[data-menu-target="panel"]`, and `#main-content`.

- [ ] **Step 1: Write the failing keyboard system test**

Create `test/system/accessibility_navigation_test.rb`:

```ruby
require "application_system_test_case"

class AccessibilityNavigationTest < ApplicationSystemTestCase
  test "mobile menu reports state and returns focus after Escape" do
    page.current_window.resize_to(320, 800)
    visit "/en"

    button = find('[data-menu-target="button"]')
    button.send_keys(:enter)
    assert_equal "true", button["aria-expanded"]
    assert_selector '[data-menu-target="panel"]:not([hidden])'

    page.send_keys(:escape)
    assert_equal "false", button["aria-expanded"]
    assert_selector '[data-menu-target="panel"][hidden]', visible: :all
    assert page.evaluate_script('document.activeElement === document.querySelector("[data-menu-target=button]")')
  end

  test "skip link moves keyboard focus to main content" do
    visit "/en"

    page.send_keys(:tab)
    assert_equal "skip-link", page.evaluate_script("document.activeElement.className")
    page.send_keys(:enter)
    assert_equal "main-content", page.evaluate_script("document.activeElement.id")
  end
end
```

- [ ] **Step 2: Run the test and observe the missing ARIA/focus behavior**

Run: `bin/rails test:system test/system/accessibility_navigation_test.rb`

Expected: FAIL on menu state, focus return, or skip-link focus.

- [ ] **Step 3: Use a native button and stable menu targets in the layout**

Ensure the first focusable element in `<body>` is:

```erb
<a class="skip-link" href="#main-content"><%= t("navigation.skip_to_content", default: "Skip to content") %></a>
```

Use this contract for the mobile menu wrapper, button, and panel while retaining existing localized links:

```erb
<nav aria-label="<%= t("navigation.primary", default: "Primary") %>" data-controller="menu" data-action="keydown.esc@window->menu#escape">
  <button type="button"
          aria-expanded="false"
          aria-controls="primary-navigation"
          data-menu-target="button"
          data-action="menu#toggle">
    <span class="sr-only"><%= t("navigation.menu", default: "Menu") %></span>
    <span aria-hidden="true">Menu</span>
  </button>
  <div id="primary-navigation" data-menu-target="panel" hidden>
```

Keep the existing Work, Journal, About, Résumé, Contact, locale-switcher, and theme-toggle children directly inside that div, then retain its existing closing `</div></nav>`. This step changes only the surrounding element attributes and menu button; it must not delete, duplicate, or reorder a navigation child. Ensure every public page has exactly one `<main id="main-content" tabindex="-1">`.

- [ ] **Step 4: Replace the menu controller with deterministic state handling**

Set `app/javascript/controllers/menu_controller.js` to:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "panel"];

  connect() {
    this.setOpen(false);
  }

  toggle() {
    this.setOpen(this.buttonTarget.getAttribute("aria-expanded") !== "true");
  }

  close() {
    this.setOpen(false);
  }

  escape(event) {
    if (this.buttonTarget.getAttribute("aria-expanded") === "true") {
      event.preventDefault();
      this.setOpen(false);
      this.buttonTarget.focus();
    }
  }

  setOpen(open) {
    this.buttonTarget.setAttribute("aria-expanded", String(open));
    this.panelTarget.hidden = !open;
  }
}
```

- [ ] **Step 5: Add native focus, touch, overflow, and reduced-motion CSS**

Add this component layer to `app/assets/tailwind/application.css`, using the existing Tailwind file syntax:

```css
@layer base {
  html {
    overflow-wrap: break-word;
  }

  body {
    overflow-x: clip;
  }

  img,
  video,
  svg {
    max-width: 100%;
    height: auto;
  }

  :focus-visible {
    outline: 3px solid var(--color-focus, var(--color-accent));
    outline-offset: 3px;
  }

  @media (prefers-reduced-motion: reduce) {
    html:focus-within {
      scroll-behavior: auto;
    }

    *,
    *::before,
    *::after {
      scroll-behavior: auto !important;
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }
}

@layer components {
  .skip-link {
    position: fixed;
    inset-block-start: 0.5rem;
    inset-inline-start: 0.5rem;
    z-index: 100;
    transform: translateY(-200%);
    background: var(--color-surface);
    color: var(--color-text);
    padding: 0.75rem 1rem;
  }

  .skip-link:focus {
    transform: translateY(0);
  }

  button,
  input[type="submit"],
  .button,
  [data-menu-target="panel"] a,
  [data-theme-target="toggle"] {
    min-block-size: 44px;
    min-inline-size: 44px;
  }
}
```

Do not use `outline: none`. Do not hide focus unless `:focus-visible` supplies an equal or stronger replacement.

Add these keys under the existing locale roots; remove the `default:` arguments from the three layout `t(...)` calls after these translations exist:

```yaml
# en.yml
navigation:
  skip_to_content: "Skip to content"
  primary: "Primary navigation"
  menu: "Menu"

# fr.yml
navigation:
  skip_to_content: "Aller au contenu"
  primary: "Navigation principale"
  menu: "Menu"

# vi.yml
navigation:
  skip_to_content: "Đi đến nội dung"
  primary: "Điều hướng chính"
  menu: "Trình đơn"
```

Merge each `navigation:` mapping into that file's existing locale root and existing `navigation:` mapping; do not create duplicate YAML keys.

- [ ] **Step 6: Verify keyboard behavior and reduced-motion CSS**

Run:

```bash
bin/rails test:system test/system/accessibility_navigation_test.rb
bin/rails test test/requests/locale_routing_test.rb
```

Expected: PASS at 320px; Enter opens the menu, Escape closes it, and focus returns to the button.

- [ ] **Step 7: Commit the accessibility interaction changes**

```bash
git add app/javascript/controllers/menu_controller.js app/views/layouts/application.html.erb app/assets/tailwind/application.css config/locales test/system/accessibility_navigation_test.rb
git commit -m "fix: complete keyboard and reduced motion support"
```

---

### Task 6: Theme, Accent Contrast, 320px, and 200% Zoom Regression Suite

**Files:**

- Modify: `app/assets/tailwind/application.css`
- Create: `test/system/release_quality_test.rb`

**Interfaces:**

- Consumes: Phase 1 `html[data-accent]`, `html[data-theme]`, localStorage key `portfolio-theme`, Phase 3 `sign_in_owner`, and seeded/fixture public records.
- Produces: exact `--color-background`, `--color-surface`, `--color-text`, `--color-accent`, `--color-accent-foreground`, and `--color-focus` browser tokens.

- [ ] **Step 1: Add the failing browser-level release tests**

Create `test/system/release_quality_test.rb`:

```ruby
require "application_system_test_case"

class ReleaseQualityTest < ApplicationSystemTestCase
  ACCENTS = %w[brown green lime orange yellow].freeze

  test "saved theme applies after reload and every accent passes AA" do
    profile = Profile.current

    %w[light dark].each do |theme|
      ACCENTS.each do |accent|
        profile.update!(accent: accent)
        visit "/en"
        page.execute_script("localStorage.setItem('portfolio-theme', arguments[0]); location.reload()", theme)
        assert_equal theme, find("html", visible: :all)["data-theme"]
        assert_equal accent, find("html", visible: :all)["data-accent"]
        assert_operator contrast("--color-text", "--color-background"), :>=, 4.5,
          "#{theme}/#{accent} text must pass WCAG AA"
        assert_operator contrast("--color-accent", "--color-background"), :>=, 4.5,
          "#{theme}/#{accent} accent must pass WCAG AA"
        assert_operator contrast("--color-accent-foreground", "--color-accent"), :>=, 4.5,
          "#{theme}/#{accent} filled control must pass WCAG AA"
      end
    end
  end

  test "public pages do not overflow at 320 CSS pixels or simulated 200 percent zoom" do
    public_paths.each do |path|
      page.current_window.resize_to(320, 900)
      visit path
      assert_no_horizontal_overflow(path, "320px")

      page.current_window.resize_to(640, 900)
      visit path
      page.execute_script("document.documentElement.style.zoom = '2'")
      assert_no_horizontal_overflow(path, "200% zoom")
    end
  end

  test "admin pages do not overflow at 320 CSS pixels or simulated 200 percent zoom" do
    sign_in_owner

    %w[/admin /admin/projects /admin/posts /admin/tags /admin/profile /admin/resume /admin/messages].each do |path|
      page.current_window.resize_to(320, 900)
      visit path
      assert_no_horizontal_overflow(path, "320px")

      page.current_window.resize_to(640, 900)
      visit path
      page.execute_script("document.documentElement.style.zoom = '2'")
      assert_no_horizontal_overflow(path, "200% zoom")
    end
  end

  test "primary mobile controls meet the 44 pixel target" do
    page.current_window.resize_to(320, 900)
    visit "/en"
    find('[data-menu-target="button"]').click

    all('button, input[type="submit"], [data-menu-target="panel"] a', visible: :visible).each do |element|
      box = page.evaluate_script(<<~JS, element)
        const rect = arguments[0].getBoundingClientRect()
        return { width: rect.width, height: rect.height }
      JS
      assert_operator box.fetch("width"), :>=, 44, element.text
      assert_operator box.fetch("height"), :>=, 44, element.text
    end
  end

  test "reduced motion removes meaningful transition duration" do
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [{ name: "prefers-reduced-motion", value: "reduce" }]
    )
    visit "/en"

    duration = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector('[data-menu-target="button"]')).transitionDuration
    JS
    assert_includes ["0s", "0.00001s"], duration
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  private

  def public_paths
    project = ProjectTranslation.publicly_visible(locale: "en").first!
    post = PostTranslation.publicly_visible(locale: "en").first!
    [
      "/en", "/en/projects", "/en/projects/#{project.slug}",
      "/en/blog", "/en/blog/#{post.slug}", "/en/about",
      "/en/resume", "/en/contact"
    ]
  end

  def assert_no_horizontal_overflow(path, mode)
    dimensions = page.evaluate_script(<<~JS)
      ({ scrollWidth: document.documentElement.scrollWidth,
         clientWidth: document.documentElement.clientWidth })
    JS
    assert_operator dimensions.fetch("scrollWidth"), :<=, dimensions.fetch("clientWidth") + 1,
      "#{path} overflows at #{mode}: #{dimensions.inspect}"
  end

  def contrast(first_token, second_token)
    colors = page.evaluate_script(<<~JS, first_token, second_token)
      const style = getComputedStyle(document.documentElement)
      return [style.getPropertyValue(arguments[0]), style.getPropertyValue(arguments[1])]
    JS
    luminances = colors.map { |color| relative_luminance(color) }
    lighter, darker = luminances.max, luminances.min
    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(css_color)
    value = css_color.strip
    channels = if value.start_with?("#")
      value.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    else
      value.scan(/[\d.]+/).first(3).map { |channel| channel.to_f / 255.0 }
    end
    linear = channels.map { |channel| channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
    (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
  end
end
```

- [ ] **Step 2: Run the suite and capture the first failing token or page**

Run:

```bash
bin/rails test:system test/system/release_quality_test.rb
```

Expected: FAIL until all semantic tokens have the exact values below and any page-specific overflow is corrected.

- [ ] **Step 3: Define the approved theme and accent tokens once**

Merge this into the base layer of `app/assets/tailwind/application.css`, replacing duplicate hard-coded theme/accent declarations:

```css
@layer base {
  :root {
    color-scheme: light dark;
    --color-background: #f3f0e8;
    --color-surface: #ffffff;
    --color-text: #151512;
    --color-muted: #514f48;
    --color-accent: var(--accent-light);
    --color-accent-foreground: #f4f1e8;
    --color-focus: var(--color-accent);
  }

  html[data-theme="dark"] {
    --color-background: #0d0d0d;
    --color-surface: #1a1a18;
    --color-text: #f4f1e8;
    --color-muted: #c9c5ba;
    --color-accent: var(--accent-dark);
    --color-accent-foreground: #151512;
  }

  html[data-theme="light"] {
    --color-background: #f3f0e8;
    --color-surface: #ffffff;
    --color-text: #151512;
    --color-muted: #514f48;
    --color-accent: var(--accent-light);
    --color-accent-foreground: #f4f1e8;
  }

  @media (prefers-color-scheme: dark) {
    html:not([data-theme]) {
      --color-background: #0d0d0d;
      --color-surface: #1a1a18;
      --color-text: #f4f1e8;
      --color-muted: #c9c5ba;
      --color-accent: var(--accent-dark);
      --color-accent-foreground: #151512;
    }
  }

  html[data-accent="brown"] {
    --accent-dark: #c58a63;
    --accent-light: #7a4e35;
  }
  html[data-accent="green"] {
    --accent-dark: #5bc98b;
    --accent-light: #216e46;
  }
  html[data-accent="lime"] {
    --accent-dark: #baff54;
    --accent-light: #5a7600;
  }
  html[data-accent="orange"] {
    --accent-dark: #ff8a3d;
    --accent-light: #a94300;
  }
  html[data-accent="yellow"] {
    --accent-dark: #ffd84d;
    --accent-light: #806100;
  }

  body {
    background: var(--color-background);
    color: var(--color-text);
  }
}
```

Keep `lime` as the model/database default. Replace remaining literal accent colors in components with `var(--color-accent)` and filled-control text with `var(--color-accent-foreground)`; do not create visitor-defined accent values.

- [ ] **Step 4: Fix only concrete overflow failures reported by the test**

Use these bounded rules in the existing components instead of adding JavaScript resize behavior:

```css
.content-container {
  width: min(100% - 2rem, 72rem);
  margin-inline: auto;
}
.prose,
pre,
code {
  max-inline-size: 100%;
}
pre {
  overflow-x: auto;
}
.admin-record,
.content-card {
  min-inline-size: 0;
}
.admin-table-wrap {
  max-inline-size: 100%;
  overflow-x: auto;
}
input,
textarea,
select {
  max-inline-size: 100%;
}
```

Apply `.admin-table-wrap` only around a table that cannot become the Phase 4 labeled mobile cards. Do not hide actions or reorder source content to make the test pass.

- [ ] **Step 5: Run the focused system suites in both default browser modes**

Run:

```bash
bin/rails test:system test/system/release_quality_test.rb test/system/accessibility_navigation_test.rb test/system/theme_test.rb test/system/admin_content_management_test.rb
```

Expected: PASS for all ten theme/accent combinations, all listed public/admin pages, reduced motion, touch targets, and keyboard navigation.

- [ ] **Step 6: Commit tokens and release regressions**

```bash
git add app/assets/tailwind/application.css test/system/release_quality_test.rb
git commit -m "test: enforce release presentation quality"
```

---

### Task 7: Full Review Gate and Release Evidence

**Files:**

- Review only; do not create a dependency report, screenshot bundle, or generated audit artifact in Git.

**Interfaces:**

- Consumes: all Phase 1–7 behavior.
- Produces: a green phase gate and one signed commit history; no new runtime interface.

- [ ] **Step 1: Check the phase diff for scope and accidental dependencies**

Run:

```bash
git status --short
git diff --check
git log --oneline --max-count=6
bundle check
bin/importmap json >/dev/null
```

Expected: no uncommitted files, no whitespace errors, dependencies satisfied, import map valid, and exactly the focused Phase 7 commits above at the tip. `Gemfile`, `package.json`, and import-map pins are unchanged.

- [ ] **Step 2: Run static application checks**

Run:

```bash
bin/rubocop
bin/brakeman --no-pager
```

Expected: both exit 0; Brakeman reports no warnings involving raw JSON-LD, exception output, or unescaped sitemap values.

- [ ] **Step 3: Run every automated test**

Run:

```bash
RAILS_ENV=test bin/rails db:test:prepare
bin/rails test
bin/rails test:system
```

Expected: all model, job, mailer, request, helper, and system tests pass with zero failures and zero errors.

- [ ] **Step 4: Inspect metadata and sitemap over a real local HTTP server**

In terminal 1 run:

```bash
bin/rails db:seed
bin/rails server -b 127.0.0.1 -p 3000
```

In terminal 2 run:

```bash
curl -fsS http://127.0.0.1:3000/en | grep -E '<title>|canonical|hreflang|og:|application/ld\+json'
curl -fsS http://127.0.0.1:3000/sitemap.xml | xmllint --noout -
curl -fsS http://127.0.0.1:3000/sitemap.xml | grep -E '/(en|fr|vi)(/|<)'
curl -fsS -H 'Accept-Language: fr' http://127.0.0.1:3000/404 | grep -E 'Page introuvable|noindex,nofollow'
```

Expected: metadata is absolute and localized, `xmllint` exits 0, sitemap entries use only supported locale prefixes, and the error response is French and non-indexable. Open a draft translation in admin and verify its URL appears in neither page source nor sitemap output.

- [ ] **Step 5: Complete the exact responsive and zoom browser matrix**

Open Chrome DevTools, disable cache, and check `/en`, one project detail, one post detail, `/en/contact`, `/admin/projects`, one admin edit form, and `/admin/messages` at each viewport:

| Mode            | CSS viewport |
| --------------- | ------------ |
| Phone portrait  | 320 × 568    |
| Phone landscape | 568 × 320    |
| Tablet          | 768 × 1024   |
| Laptop          | 1280 × 800   |
| Desktop         | 1440 × 900   |
| Large desktop   | 1920 × 1080  |

At each width verify: no horizontal page scrollbar; source order matches visual/tab order; every action remains present; text does not collide or clip; images choose a sensible `currentSrc`; and navigation does not require hover. Then set Chrome page zoom to **200%** at 1280 × 800 and repeat all seven URLs. Pass only if content reflows without a horizontal page scrollbar; horizontally scrolling code blocks and irreducible admin tables may scroll inside their own labeled container.

- [ ] **Step 6: Complete the exact keyboard, motion, theme, and accent review**

Using only `Tab`, `Shift+Tab`, `Enter`, `Space`, and `Escape`:

1. Traverse the skip link, site mark, mobile menu, five primary links, language switcher, theme toggle, contact form, and admin form actions.
2. Verify focus is visible on every stop, the menu reports expanded/collapsed state, Escape closes it and returns focus, and destructive confirmations remain keyboard operable.
3. Enable macOS **System Settings → Accessibility → Display → Reduce motion**, reload, and verify menu/theme/Turbo feedback has no sliding, zooming, or long fade.
4. Remove the saved theme override and verify light/dark follows the operating-system setting without an incorrect-theme flash.
5. Select light, reload, then select dark and reload; verify the override persists.
6. In admin choose Brown, Green, Lime, Orange, and Yellow in turn; for each preset inspect one public page in light and dark and verify the selected accent persists while labels, focus rings, links, and filled controls stay readable.

Expected: every step is operable without a pointer, focus is never obscured, motion reduction is honored, and all ten theme/accent combinations match the automated contrast assertions.

- [ ] **Step 7: Inspect responsive image network behavior**

In Chrome Network, filter to `Img`, disable cache, and reload a project index at 320px and 1440px. Expected: image elements expose `srcset` and `sizes`, the 320px viewport does not fetch the 1280/1600 variant for cards, below-fold images are lazy, the detail hero is eager/high priority, intrinsic dimensions reserve layout space, and missing images show the Phase 2 text fallback.

- [ ] **Step 8: Record the phase boundary without changing the immutable parent plan**

Run:

```bash
git status --short
git tag -a portfolio-v4-phase-07 -m "Portfolio v4 phase 7: release quality"
git show --stat --oneline portfolio-v4-phase-07
```

Expected: working tree clean and the tag points to the final Phase 7 commit. Do not edit `docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md` or the approved spec to mark completion.

## Risks and Review Triggers

- **Route-name drift:** resolve once with `bin/rails routes`; do not duplicate routes or hard-code a second routing scheme.
- **Publication leaks:** metadata and sitemap must query `publicly_visible(locale:)`; a direct `state == "published"` check is not equivalent if publication timestamps participate in visibility.
- **Layout render order:** templates call `page_metadata` before the layout reads `page_metadata_values`; controller redirects and non-HTML responses must not invoke metadata rendering.
- **JSON-LD injection:** keep `json_escape(...to_json)` and never use authored Markdown HTML as raw JSON-LD.
- **Variant cost:** four native variants per rendered image are sufficient. Add no CDN, picture service, or eager pre-generation until production measurements justify it.
- **Error recursion:** the error controller must not load optional content records or raise when profile data is absent.
- **Browser zoom limits:** the scripted CSS zoom catches common reflow regressions; the real Chrome 200% review remains mandatory.
- **Contrast scope:** a passing token test does not excuse component-level opacity or blended backgrounds; inspect links, focus rings, and filled controls in the manual matrix.

## Phase Acceptance

Phase 7 is complete only when:

- Metadata has localized title/description, query-free canonical, Open Graph fields, published-only `hreflang`, and valid JSON-LD.
- `/sitemap.xml` is valid XML and contains no draft, scheduled, missing, or unpublished translation URL.
- 404, 422, and 500 are branded and localized, disclose no exception details, and emit `noindex,nofollow`.
- Public images use native Active Storage variants with `srcset`, `sizes`, localized alt text, lazy loading except priority heroes, and intrinsic dimensions.
- Keyboard, visible focus, touch target, reduced motion, saved theme, and owner accent checks pass.
- Public and admin flows pass at 320 CSS pixels and real 200% browser zoom without page-level horizontal overflow.
- `bin/rubocop`, `bin/brakeman --no-pager`, `bin/rails test`, and `bin/rails test:system` all exit 0.
- The browser review matrix is complete, the tree is clean, and annotated tag `portfolio-v4-phase-07` exists.
