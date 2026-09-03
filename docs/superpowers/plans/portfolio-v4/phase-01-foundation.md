# Portfolio v4 Phase 1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bootable Rails shell whose locale routing, responsive public navigation, theme override, and five accent presets are ready for all later portfolio features.

**Architecture:** Continue from the generated server-rendered Rails monolith at the repository root and keep Phase 1 state-free except for a locale cookie and browser-local theme override. A single `PublicController` owns locale negotiation and shell pages; ERB renders semantic navigation, Stimulus adds only menu/theme behavior, and CSS custom properties provide the mobile-first theme/accent contract.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Hotwire (Turbo and Stimulus), Tailwind CSS, SQLite, Importmap, Minitest, Capybara, Selenium

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
- Use Rails defaults and the standard library before adding dependencies. Do not add `commonmarker` or `rotp` in this phase.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.
- Use Ruby exactly `4.0.6`; retain the generated Rails 8.1 constraint and require the resolved Rails version to have major/minor `8.1`.
- Do not change the approved spec, the parent implementation plan, or anything under `tmp/`.

---

## Assumptions, boundaries, and risks

- Execution starts from scaffold commit `1df2b54`, with a clean worktree at the repository root. The Rails application already exists; do not rerun `rails new`.
- The committed baseline has `.ruby-version` set to `ruby-4.0.6`, Rails `8.1.3.1`, SQLite, Tailwind, Turbo, Stimulus, Importmap, Minitest, Capybara, and Selenium. Ruby 4.0.6 and a Chrome-compatible browser must remain available.
- Tailwind comes only from the Rails 8.1 generator (`tailwindcss-rails`); there is no Node, npm, or third-party component library.
- Phase 1 exposes top-level shell pages only: localized home, projects, blog, about, résumé, and contact. Content detail routes and résumé download are Phase 2 work because they require persisted records or attachments.
- Until the persisted `Profile` exists, `ThemeHelper#accent_preset` reads the optional server value `SITE_ACCENT` and safely defaults invalid or missing values to `lime`. Later work may replace that lookup, but must preserve the `<html data-accent="brown|green|lime|orange|yellow">` contract.
- `Accept-Language` parsing is deliberately small: it honors supported primary language subtags and `q` weights. It does not introduce a locale-negotiation gem.
- The highest-risk behavior is pre-paint theme selection. Keep the bootstrap script inline, static, and before the stylesheet; putting it in a deferred Stimulus controller would cause a visible wrong-theme flash.

## Exact file map

| Path                                                                                                                | Change   | Responsibility                                                                                     |
| ------------------------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------- |
| `.ruby-version`, `Gemfile`, `Gemfile.lock`                                                                          | Verify   | Keep the committed Ruby 4.0.6 and Rails 8.1 baseline unchanged.                                    |
| Rails-generated root, `app/`, `bin/`, `config/`, `db/`, `lib/`, `public/`, `storage/`, `test/`, and `vendor/` files | Existing | Standard Rails 8.1 SQLite/Tailwind/Hotwire application baseline from commit `1df2b54`.             |
| `config/application.rb`                                                                                             | Modify   | Restrict I18n to `en`, `fr`, and `vi`, default to English, and disable fallback.                   |
| `config/routes.rb`                                                                                                  | Modify   | Root negotiation route and six explicit locale-scoped shell routes.                                |
| `app/controllers/public_controller.rb`                                                                              | Create   | Locale cookie, `Accept-Language` negotiation, `I18n.with_locale`, URL defaults, and shell actions. |
| `app/views/public/page.html.erb`                                                                                    | Create   | Shared localized shell-page heading and introduction.                                              |
| `config/locales/en.yml`                                                                                             | Modify   | Complete English shell copy.                                                                       |
| `config/locales/fr.yml`, `config/locales/vi.yml`                                                                    | Create   | Complete French and Vietnamese shell copy with no fallback.                                        |
| `test/integration/public_localization_test.rb`                                                                      | Create   | Locale precedence, scoped routes, cookie persistence, and 404 coverage.                            |
| `app/helpers/application_helper.rb`                                                                                 | Modify   | Equivalent shell-page path generation for the language switcher.                                   |
| `app/helpers/theme_helper.rb`                                                                                       | Create   | Accent allowlist and safe pre-paint theme bootstrap.                                               |
| `app/views/layouts/application.html.erb`                                                                            | Modify   | Semantic document shell and ordered theme bootstrap/assets.                                        |
| `app/views/shared/_header.html.erb`                                                                                 | Create   | Site mark, primary navigation, locale switcher, menu button, and theme button.                     |
| `app/views/shared/_footer.html.erb`                                                                                 | Create   | Compact localized footer navigation.                                                               |
| `app/assets/tailwind/application.css`                                                                               | Modify   | Semantic light/dark/accent tokens and mobile-first responsive shell.                               |
| `test/helpers/theme_helper_test.rb`                                                                                 | Create   | Accent allowlist/default and bootstrap-script contract.                                            |
| `test/integration/public_shell_test.rb`                                                                             | Create   | Static semantic, translated, and bootstrap-order contract.                                         |
| `app/javascript/controllers/menu_controller.js`                                                                     | Create   | Accessible mobile menu open/close and Escape handling.                                             |
| `app/javascript/controllers/theme_controller.js`                                                                    | Create   | Effective theme detection, override persistence, and accessible state.                             |
| `test/application_system_test_case.rb`                                                                              | Create   | Shared Rails system-test driver configuration missing from the generated baseline.                 |
| `test/system/public_shell_test.rb`                                                                                  | Create   | Real-browser locale, menu, theme persistence, viewport, and overflow checks.                       |

Do not create a database model, migration, admin namespace, content detail route, résumé download, custom Tailwind configuration, or new dependency in this phase.

## Interfaces produced for later phases

- `PublicController#current_locale -> String`: always returns one of `"en"`, `"fr"`, or `"vi"` during a localized request.
- `PublicController#default_url_options -> Hash`: returns `{ locale: current_locale }` on localized actions so later route helpers retain locale.
- Cookie `portfolio_locale`: permanent, same-site `Lax`, and accepted only when its value is in `PublicController::SUPPORTED_LOCALES`.
- Route helpers: `localized_root_path(locale:)`, `localized_projects_path(locale:)`, `localized_blog_path(locale:)`, `localized_about_path(locale:)`, `localized_resume_path(locale:)`, and `localized_contact_path(locale:)`.
- `ApplicationHelper#locale_switch_path(locale) -> String`: returns the current shell page's equivalent path in a supported locale.
- `ThemeHelper::ACCENT_PRESETS`: exactly `%w[brown green lime orange yellow]`.
- `ThemeHelper#accent_preset(candidate = ENV["SITE_ACCENT"]) -> String`: returns an allowlisted preset or `"lime"`.
- `ThemeHelper#theme_bootstrap_script -> ActiveSupport::SafeBuffer`: emits the static inline script that applies `localStorage["portfolio-theme"]` before CSS loads.
- Root element contract: `<html lang="en|fr|vi" data-accent="brown|green|lime|orange|yellow">`; a manual mode adds `data-theme="light|dark"`.
- I18n namespaces consumed by the shell: `site.*`, `navigation.*`, `locales.*`, `menu.*`, `theme.*`, `pages.*`, and `footer.*`.
- Shared CSS classes available to later public views: `.site-container`, `.page-shell`, `.page-hero`, `.eyebrow`, and `.prose-lead`.

---

## Completed baseline — do not execute again

Commit `1df2b54` already generated and committed the Rails application. The review verified Ruby `4.0.6`, Rails `8.1.3.1`, SQLite, a clean worktree, and a passing generated `bin/rails test` run. Start implementation at Task 2; rerunning the generator would overwrite the reviewed baseline.

---

### Task 2: Add strict locale routing and negotiation

**Files:**

- Create: `app/controllers/public_controller.rb`
- Create: `app/views/public/page.html.erb`
- Modify: `config/application.rb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Create: `config/locales/fr.yml`
- Create: `config/locales/vi.yml`
- Create: `test/integration/public_localization_test.rb`

**Interfaces:**

- Consumes: generated `ApplicationController`, Rails I18n, browser cookies, and the six route helpers defined here.
- Produces: `PublicController#current_locale`, locale-preserving URL defaults, `portfolio_locale`, six localized shell routes, and complete shell translations.

- [x] **Step 1: Write the failing locale integration tests**

Create `test/integration/public_localization_test.rb`:

```ruby
require "test_helper"

class PublicLocalizationTest < ActionDispatch::IntegrationTest
  test "root falls back to English" do
    get root_path

    assert_redirected_to localized_root_path(locale: "en")
  end

  test "root chooses the supported language with the highest quality" do
    get root_path, headers: { "Accept-Language" => "de-DE, vi;q=0.8, fr-FR;q=0.9, en;q=0.7" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "root ignores invalid quality values" do
    get root_path, headers: { "Accept-Language" => "vi;q=9, fr;q=0.8" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "saved locale wins over Accept-Language" do
    get localized_about_path(locale: "vi")
    assert_response :success
    assert_equal "vi", cookies[:portfolio_locale]

    get root_path, headers: { "Accept-Language" => "fr" }

    assert_redirected_to localized_root_path(locale: "vi")
  end

  test "unsupported saved locale is ignored" do
    cookies[:portfolio_locale] = "de"

    get root_path, headers: { "Accept-Language" => "fr" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "every shell page renders in each explicit locale" do
    routes = %i[
      localized_root_path
      localized_projects_path
      localized_blog_path
      localized_about_path
      localized_resume_path
      localized_contact_path
    ]

    %w[en fr vi].product(routes).each do |locale, route|
      get public_send(route, locale: locale)
      assert_response :success, "Expected #{route} to render for #{locale}"
      assert_equal locale, cookies[:portfolio_locale]
    end
  end

  test "fixed copy comes from the active locale without fallback" do
    {
      "en" => "About",
      "fr" => "À propos",
      "vi" => "Giới thiệu"
    }.each do |locale, heading|
      get localized_about_path(locale: locale)

      assert_select "h1", text: heading
    end
  end

  test "unsupported locale segments return not found" do
    get "/de/about"

    assert_response :not_found
  end
end
```

- [x] **Step 2: Run the locale tests and verify red**

Run:

```bash
bin/rails test test/integration/public_localization_test.rb
```

Expected: FAIL with undefined localized route helpers because the locale routes do not exist.

- [x] **Step 3: Restrict Rails I18n to the three supported locales**

Inside `class Application < Rails::Application` in `config/application.rb`, add:

```ruby
config.i18n.available_locales = %i[en fr vi]
config.i18n.default_locale = :en
config.i18n.enforce_available_locales = true
config.i18n.fallbacks = false
```

Replace `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "public#root"

  scope "/:locale", locale: /en|fr|vi/ do
    get "/", to: "public#home", as: :localized_root
    get "projects", to: "public#projects", as: :localized_projects
    get "blog", to: "public#blog", as: :localized_blog
    get "about", to: "public#about", as: :localized_about
    get "resume", to: "public#resume", as: :localized_resume
    get "contact", to: "public#contact", as: :localized_contact
  end
end
```

- [x] **Step 4: Implement locale precedence, cookie persistence, and scoped rendering**

Create `app/controllers/public_controller.rb`:

```ruby
class PublicController < ApplicationController
  SUPPORTED_LOCALES = %w[en fr vi].freeze

  around_action :with_locale, except: :root
  helper_method :current_locale

  def root
    redirect_to localized_root_path(locale: preferred_locale)
  end

  def home = render_page(:home)
  def projects = render_page(:projects)
  def blog = render_page(:blog)
  def about = render_page(:about)
  def resume = render_page(:resume)
  def contact = render_page(:contact)

  def current_locale
    @current_locale || I18n.default_locale.to_s
  end

  def default_url_options
    action_name == "root" ? {} : { locale: current_locale }
  end

  private

  def render_page(page)
    render :page, locals: { page: page }
  end

  def with_locale(&action)
    @current_locale = params.fetch(:locale)
    cookies.permanent[:portfolio_locale] = {
      value: @current_locale,
      same_site: :lax
    }
    I18n.with_locale(@current_locale, &action)
  end

  def preferred_locale
    saved_locale || requested_locale || I18n.default_locale.to_s
  end

  def saved_locale
    cookies[:portfolio_locale].presence_in(SUPPORTED_LOCALES)
  end

  def requested_locale
    request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
      .split(",")
      .each_with_index
      .filter_map do |entry, index|
        language_range, *parameters = entry.strip.split(";")
        locale = language_range.downcase.split("-").first
        next unless locale.in?(SUPPORTED_LOCALES)

        quality_parameter = parameters.find { |parameter| parameter.strip.start_with?("q=") }
        quality = quality_parameter ? Float(quality_parameter.split("=", 2).last, exception: false).to_f : 1.0
        next unless quality.positive? && quality <= 1.0

        [locale, quality, index]
      end
      .max_by { |_locale, quality, index| [quality, -index] }
      &.first
  end
end
```

Create `app/views/public/page.html.erb`:

```erb
<% content_for :title, "#{t("pages.#{page}.title")} — #{t("site.name")}" %>

<main id="main-content" class="page-shell site-container">
  <header class="page-hero">
    <p class="eyebrow"><%= t("pages.#{page}.eyebrow") %></p>
    <h1><%= t("pages.#{page}.title") %></h1>
    <p class="prose-lead"><%= t("pages.#{page}.introduction") %></p>
  </header>
</main>
```

- [x] **Step 5: Add complete English shell copy**

Replace `config/locales/en.yml` with:

```yaml
en:
  site:
    name: "Portfolio"
  navigation:
    label: "Primary navigation"
    work: "Work"
    journal: "Journal"
    about: "About"
    resume: "Résumé"
    contact: "Contact"
  locales:
    label: "Choose language"
    en: "English"
    fr: "Français"
    vi: "Tiếng Việt"
  menu:
    open: "Open menu"
    close: "Close menu"
  theme:
    toggle: "Toggle color theme"
    switch_to_light: "Switch to light theme"
    switch_to_dark: "Switch to dark theme"
  pages:
    home:
      eyebrow: "Portfolio"
      title: "Ideas. Interfaces. Impact."
      introduction: "A focused home for selected work, technical writing, and ways to connect."
    projects:
      eyebrow: "Selected work"
      title: "Work"
      introduction: "Selected project case studies, outcomes, and technical decisions."
    blog:
      eyebrow: "Technical writing"
      title: "Journal"
      introduction: "Technical articles, practical notes, and engineering lessons."
    about:
      eyebrow: "Profile"
      title: "About"
      introduction: "Biography, experience, skills, and external profiles."
    resume:
      eyebrow: "Experience"
      title: "Résumé"
      introduction: "Localized experience with a direct résumé download."
    contact:
      eyebrow: "Start a conversation"
      title: "Contact"
      introduction: "A direct and secure way to start a conversation."
  footer:
    rights: "Built with care."
```

- [x] **Step 6: Add complete French shell copy**

Create `config/locales/fr.yml`:

```yaml
fr:
  site:
    name: "Portfolio"
  navigation:
    label: "Navigation principale"
    work: "Réalisations"
    journal: "Journal"
    about: "À propos"
    resume: "CV"
    contact: "Contact"
  locales:
    label: "Choisir la langue"
    en: "English"
    fr: "Français"
    vi: "Tiếng Việt"
  menu:
    open: "Ouvrir le menu"
    close: "Fermer le menu"
  theme:
    toggle: "Changer le thème de couleur"
    switch_to_light: "Passer au thème clair"
    switch_to_dark: "Passer au thème sombre"
  pages:
    home:
      eyebrow: "Portfolio"
      title: "Idées. Interfaces. Impact."
      introduction: "Un espace ciblé pour des réalisations, des écrits techniques et des prises de contact."
    projects:
      eyebrow: "Travaux sélectionnés"
      title: "Réalisations"
      introduction: "Des études de cas, leurs résultats et leurs décisions techniques."
    blog:
      eyebrow: "Écrits techniques"
      title: "Journal"
      introduction: "Des articles techniques, des notes pratiques et des retours d’expérience."
    about:
      eyebrow: "Profil"
      title: "À propos"
      introduction: "Biographie, expérience, compétences et profils externes."
    resume:
      eyebrow: "Expérience"
      title: "CV"
      introduction: "Une expérience localisée avec un téléchargement direct du CV."
    contact:
      eyebrow: "Échangeons"
      title: "Contact"
      introduction: "Un moyen direct et sécurisé de commencer une conversation."
  footer:
    rights: "Conçu avec soin."
```

- [x] **Step 7: Add complete Vietnamese shell copy**

Create `config/locales/vi.yml`:

```yaml
vi:
  site:
    name: "Portfolio"
  navigation:
    label: "Điều hướng chính"
    work: "Dự án"
    journal: "Nhật ký"
    about: "Giới thiệu"
    resume: "Hồ sơ"
    contact: "Liên hệ"
  locales:
    label: "Chọn ngôn ngữ"
    en: "English"
    fr: "Français"
    vi: "Tiếng Việt"
  menu:
    open: "Mở trình đơn"
    close: "Đóng trình đơn"
  theme:
    toggle: "Đổi giao diện màu"
    switch_to_light: "Chuyển sang giao diện sáng"
    switch_to_dark: "Chuyển sang giao diện tối"
  pages:
    home:
      eyebrow: "Portfolio"
      title: "Ý tưởng. Giao diện. Tác động."
      introduction: "Nơi tập trung các dự án tiêu biểu, bài viết kỹ thuật và cách kết nối."
    projects:
      eyebrow: "Dự án tiêu biểu"
      title: "Dự án"
      introduction: "Các dự án tiêu biểu, kết quả và quyết định kỹ thuật."
    blog:
      eyebrow: "Bài viết kỹ thuật"
      title: "Nhật ký"
      introduction: "Bài viết kỹ thuật, ghi chú thực tiễn và bài học kỹ nghệ."
    about:
      eyebrow: "Hồ sơ cá nhân"
      title: "Giới thiệu"
      introduction: "Tiểu sử, kinh nghiệm, kỹ năng và hồ sơ bên ngoài."
    resume:
      eyebrow: "Kinh nghiệm"
      title: "Hồ sơ"
      introduction: "Kinh nghiệm theo ngôn ngữ cùng bản hồ sơ tải trực tiếp."
    contact:
      eyebrow: "Bắt đầu trò chuyện"
      title: "Liên hệ"
      introduction: "Một cách trực tiếp và an toàn để bắt đầu trò chuyện."
  footer:
    rights: "Được xây dựng cẩn thận."
```

- [x] **Step 8: Run the focused and full tests**

Run:

```bash
bin/rails test test/integration/public_localization_test.rb
bin/rails test
```

Expected: both commands exit 0; the focused file reports 8 tests with 0 failures and 0 errors.

- [x] **Step 9: Commit strict localization**

```bash
git add app/controllers/public_controller.rb app/views/public/page.html.erb config/application.rb config/routes.rb config/locales/en.yml config/locales/fr.yml config/locales/vi.yml test/integration/public_localization_test.rb
git commit -m "feat: add localized public shell routes"
```

---

### Task 3: Build the semantic responsive shell and theme tokens

**Files:**

- Modify: `app/helpers/application_helper.rb`
- Create: `app/helpers/theme_helper.rb`
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/shared/_header.html.erb`
- Create: `app/views/shared/_footer.html.erb`
- Modify: `app/assets/tailwind/application.css`
- Create: `test/helpers/theme_helper_test.rb`
- Create: `test/integration/public_shell_test.rb`

**Interfaces:**

- Consumes: `current_locale`, the six localized route helpers, all Task 2 I18n keys, generated asset helpers, and `SITE_ACCENT`.
- Produces: `locale_switch_path`, `accent_preset`, `theme_bootstrap_script`, semantic header/footer markup, root data attributes, and shared responsive CSS classes.

- [x] **Step 1: Write failing helper tests for accent and pre-paint theme behavior**

Create `test/helpers/theme_helper_test.rb`:

```ruby
require "test_helper"

class ThemeHelperTest < ActionView::TestCase
  def content_security_policy_nonce = "test-nonce"

  test "accepts exactly the five accent presets" do
    assert_equal %w[brown green lime orange yellow], ThemeHelper::ACCENT_PRESETS

    ThemeHelper::ACCENT_PRESETS.each do |preset|
      assert_equal preset, accent_preset(preset)
    end
  end

  test "defaults missing or invalid accents to lime" do
    assert_equal "lime", accent_preset(nil)
    assert_equal "lime", accent_preset("purple")
  end

  test "bootstrap reads only a valid saved light or dark override" do
    script = theme_bootstrap_script

    assert_includes script, 'localStorage.getItem("portfolio-theme")'
    assert_includes script, 'theme === "light" || theme === "dark"'
    assert_includes script, "document.documentElement.dataset.theme = theme"
  end
end
```

- [x] **Step 2: Write the failing static shell integration tests**

Create `test/integration/public_shell_test.rb`:

```ruby
require "test_helper"

class PublicShellTest < ActionDispatch::IntegrationTest
  test "layout exposes semantic locale accent navigation and controls" do
    get localized_root_path(locale: "en")

    assert_response :success
    assert_select "html[lang='en'][data-accent='lime']"
    assert_select "a.skip-link[href='#main-content']", text: "Skip to content"
    assert_select "header.site-header"
    assert_select "nav#primary-navigation[aria-label='Primary navigation']"
    assert_select "button[aria-controls='primary-navigation'][aria-expanded='false']"
    assert_select "nav.locale-switcher[aria-label='Choose language'] a", count: 3
    assert_select "button[data-controller='theme'][data-theme-target='toggle']"
    assert_select "footer.site-footer"
  end

  test "saved-theme bootstrap appears before the stylesheet" do
    get localized_root_path(locale: "en")

    script_position = response.body.index('localStorage.getItem("portfolio-theme")')
    stylesheet_position = response.body.index('rel="stylesheet"')

    assert script_position, "Expected inline theme bootstrap"
    assert stylesheet_position, "Expected stylesheet link"
    assert_operator script_position, :<, stylesheet_position
  end

  test "French shell uses translated accessible labels" do
    get localized_projects_path(locale: "fr")

    assert_select "html[lang='fr']"
    assert_select "nav[aria-label='Navigation principale']"
    assert_select "a[aria-current='page']", text: "Réalisations"
    assert_select "a[href='#{localized_projects_path(locale: "vi")}']", text: "Tiếng Việt"
  end
end
```

The green implementation also needs one fixed skip-link key under `en:`, `fr:`, and `vi:` respectively. Keep these exact snippets with the test, but do not add them to the locale files until Step 4, after the failing run:

```yaml
accessibility:
  skip_to_content: "Skip to content"
```

```yaml
accessibility:
  skip_to_content: "Aller au contenu"
```

```yaml
accessibility:
  skip_to_content: "Chuyển đến nội dung"
```

- [x] **Step 3: Run the helper and shell tests and verify red**

Run:

```bash
bin/rails test test/helpers/theme_helper_test.rb test/integration/public_shell_test.rb
```

Expected: FAIL because `ThemeHelper::ACCENT_PRESETS`, `accent_preset`, and the semantic shell do not exist.

- [x] **Step 4: Add equivalent locale paths, accessibility copy, and the theme helper**

Add the three `accessibility.skip_to_content` snippets from Step 2 to their respective locale files.

Replace `app/helpers/application_helper.rb` with:

```ruby
module ApplicationHelper
  def locale_switch_path(locale)
    url_for(only_path: true, locale: locale)
  end
end
```

Rails merges the current route parameters, so this keeps each fixed shell page equivalent without maintaining a second route map.

Create `app/helpers/theme_helper.rb`:

```ruby
module ThemeHelper
  ACCENT_PRESETS = %w[brown green lime orange yellow].freeze

  def accent_preset(candidate = ENV["SITE_ACCENT"])
    candidate.to_s.presence_in(ACCENT_PRESETS) || "lime"
  end

  def theme_bootstrap_script
    javascript_tag nonce: true do
      <<~JAVASCRIPT.html_safe
        (() => {
          const theme = localStorage.getItem("portfolio-theme");
          if (theme === "light" || theme === "dark") {
            document.documentElement.dataset.theme = theme;
          }
        })();
      JAVASCRIPT
    end
  end
end
```

The script contains no interpolated or user-provided data. Keep it in `<head>` before CSS rather than moving it to an external deferred module.

- [x] **Step 5: Replace the generated layout with the semantic document shell**

Replace `app/views/layouts/application.html.erb` with:

```erb
<!DOCTYPE html>
<html lang="<%= current_locale %>" data-accent="<%= accent_preset %>">
  <head>
    <title><%= content_for(:title) || t("site.name") %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= theme_bootstrap_script %>
    <%= yield :head %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <a class="skip-link" href="#main-content"><%= t("accessibility.skip_to_content") %></a>
    <%= render "shared/header" %>
    <%= yield %>
    <%= render "shared/footer" %>
  </body>
</html>
```

- [x] **Step 6: Add the accessible public header**

Create `app/views/shared/_header.html.erb`:

```erb
<header
  class="site-header"
  data-controller="menu"
  data-menu-open-label-value="<%= t("menu.open") %>"
  data-menu-close-label-value="<%= t("menu.close") %>">
  <div class="site-container header-grid">
    <%= link_to localized_root_path(locale: current_locale), class: "site-mark", aria: { label: t("site.name") } do %>
      <span aria-hidden="true">P/04</span>
    <% end %>

    <button
      class="menu-button"
      type="button"
      aria-controls="primary-navigation"
      aria-expanded="false"
      data-menu-target="button"
      data-action="menu#toggle">
      <span data-menu-target="label"><%= t("menu.open") %></span>
    </button>

    <nav
      id="primary-navigation"
      class="primary-navigation"
      aria-label="<%= t("navigation.label") %>"
      data-menu-target="panel"
      hidden>
      <% [
        ["projects", t("navigation.work"), localized_projects_path(locale: current_locale)],
        ["blog", t("navigation.journal"), localized_blog_path(locale: current_locale)],
        ["about", t("navigation.about"), localized_about_path(locale: current_locale)],
        ["resume", t("navigation.resume"), localized_resume_path(locale: current_locale)],
        ["contact", t("navigation.contact"), localized_contact_path(locale: current_locale)]
      ].each do |target_action, label, path| %>
        <%= link_to label, path, aria: { current: ("page" if action_name == target_action) } %>
      <% end %>
    </nav>

    <nav class="locale-switcher" aria-label="<%= t("locales.label") %>">
      <% PublicController::SUPPORTED_LOCALES.each do |locale| %>
        <%= link_to t("locales.#{locale}"), locale_switch_path(locale),
          lang: locale,
          hreflang: locale,
          aria: { current: ("true" if locale == current_locale) } %>
      <% end %>
    </nav>

    <button
      class="theme-button"
      type="button"
      data-controller="theme"
      data-theme-target="toggle"
      data-theme-light-label-value="<%= t("theme.switch_to_light") %>"
      data-theme-dark-label-value="<%= t("theme.switch_to_dark") %>"
      data-action="theme#toggle"
      aria-label="<%= t("theme.toggle") %>">
      <%= t("theme.toggle") %>
    </button>
  </div>
</header>
```

- [x] **Step 7: Add the compact public footer**

Create `app/views/shared/_footer.html.erb`:

```erb
<footer class="site-footer">
  <div class="site-container footer-grid">
    <p><%= t("footer.rights") %></p>
    <%= link_to t("navigation.contact"), localized_contact_path(locale: current_locale) %>
  </div>
</footer>
```

- [x] **Step 8: Replace the Tailwind entrypoint with complete mobile-first tokens and shell styles**

Replace `app/assets/tailwind/application.css` with the following. Everything after the `@import` lives inside `@layer base { ... }`: Tailwind v4 preflight ships a layered `[hidden] { display: none !important }` rule, and layered `!important` beats unlayered `!important`, so unlayered shell CSS would break the desktop navigation override.

```css
@import "tailwindcss";

@layer base {
:root {
  color-scheme: light;
  --background: #f3f0e8;
  --foreground: #151512;
  --muted: #5f5c54;
  --surface: #e7e2d6;
  --border: #b9b2a4;
  --accent: var(--accent-light);
  --accent-foreground: #ffffff;
  --focus: var(--accent);
  --font-display:
    ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
    sans-serif;
  --font-body:
    ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
    sans-serif;
}

:root[data-accent="brown"] {
  --accent-dark: #c58a63;
  --accent-light: #7a4e35;
}
:root[data-accent="green"] {
  --accent-dark: #5bc98b;
  --accent-light: #216e46;
}
:root[data-accent="lime"] {
  --accent-dark: #baff54;
  --accent-light: #5a7600;
}
:root[data-accent="orange"] {
  --accent-dark: #ff8a3d;
  --accent-light: #a94300;
}
:root[data-accent="yellow"] {
  --accent-dark: #ffd84d;
  --accent-light: #806100;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) {
    color-scheme: dark;
    --background: #0d0d0d;
    --foreground: #f4f1e8;
    --muted: #b9b4a9;
    --surface: #191918;
    --border: #45433e;
    --accent: var(--accent-dark);
    --accent-foreground: #151512;
  }
}

:root[data-theme="light"] {
  color-scheme: light;
  --background: #f3f0e8;
  --foreground: #151512;
  --muted: #5f5c54;
  --surface: #e7e2d6;
  --border: #b9b2a4;
  --accent: var(--accent-light);
  --accent-foreground: #ffffff;
}

:root[data-theme="dark"] {
  color-scheme: dark;
  --background: #0d0d0d;
  --foreground: #f4f1e8;
  --muted: #b9b4a9;
  --surface: #191918;
  --border: #45433e;
  --accent: var(--accent-dark);
  --accent-foreground: #151512;
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  background: var(--background);
  color: var(--foreground);
  font-family: var(--font-body);
  line-height: 1.5;
  text-rendering: optimizeLegibility;
}

body {
  min-width: 0;
  min-height: 100vh;
  margin: 0;
  overflow-wrap: anywhere;
  background: var(--background);
  color: var(--foreground);
}

img,
svg,
video {
  display: block;
  max-width: 100%;
  height: auto;
}

a {
  color: inherit;
  text-decoration-thickness: 0.12em;
  text-underline-offset: 0.2em;
}

a:hover {
  color: var(--accent);
}

button,
a {
  -webkit-tap-highlight-color: transparent;
}

button {
  min-height: 2.75rem;
  border: 1px solid var(--border);
  border-radius: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  cursor: pointer;
}

:focus-visible {
  outline: 3px solid var(--focus);
  outline-offset: 3px;
}

[hidden] {
  display: none !important;
}

.site-container {
  width: min(calc(100% - 2rem), 80rem);
  margin-inline: auto;
}

.skip-link {
  position: fixed;
  z-index: 100;
  top: 0.5rem;
  left: 0.5rem;
  padding: 0.75rem 1rem;
  transform: translateY(-150%);
  background: var(--accent);
  color: var(--accent-foreground);
  font-weight: 800;
}

.skip-link:focus {
  transform: translateY(0);
}

.site-header {
  border-bottom: 1px solid var(--border);
}

.header-grid {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  gap: 0.75rem;
  padding-block: 0.75rem;
}

.site-mark {
  display: inline-flex;
  width: fit-content;
  min-height: 2.75rem;
  align-items: center;
  font-family: var(--font-display);
  font-size: 1.125rem;
  font-weight: 900;
  letter-spacing: -0.04em;
  text-decoration: none;
}

.menu-button,
.theme-button {
  padding-inline: 0.875rem;
  font-size: 0.75rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.primary-navigation {
  grid-column: 1 / -1;
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--border);
}

.primary-navigation a {
  display: flex;
  min-height: 2.75rem;
  align-items: center;
  border-bottom: 1px solid var(--border);
  font-size: 0.875rem;
  font-weight: 750;
  letter-spacing: 0.05em;
  text-decoration: none;
  text-transform: uppercase;
}

.primary-navigation a[aria-current="page"] {
  color: var(--accent);
}

.locale-switcher {
  grid-column: 1 / -1;
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem 0.875rem;
}

.locale-switcher a {
  display: inline-flex;
  min-height: 2.75rem;
  align-items: center;
  font-size: 0.75rem;
  font-weight: 700;
}

.locale-switcher a[aria-current="true"] {
  color: var(--accent);
  text-decoration-thickness: 0.2em;
}

.theme-button {
  grid-column: 1 / -1;
  justify-self: start;
}

.page-shell {
  min-height: min(68vh, 48rem);
  padding-block: clamp(3rem, 12vw, 8rem);
}

.page-hero {
  max-width: 68rem;
}

.eyebrow {
  margin: 0 0 1rem;
  color: var(--accent);
  font-size: 0.75rem;
  font-weight: 850;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

h1 {
  max-width: 12ch;
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(3rem, 15vw, 9rem);
  font-weight: 900;
  letter-spacing: -0.065em;
  line-height: 0.9;
}

.prose-lead {
  max-width: 42rem;
  margin: 2rem 0 0;
  color: var(--muted);
  font-size: clamp(1.125rem, 4vw, 1.5rem);
}

.site-footer {
  border-top: 1px solid var(--border);
}

.footer-grid {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem 1.5rem;
  padding-block: 1.5rem;
  color: var(--muted);
  font-size: 0.875rem;
}

.footer-grid p {
  margin: 0;
}

.footer-grid a {
  min-height: 2.75rem;
  display: inline-flex;
  align-items: center;
}

@media (min-width: 56rem) {
  .header-grid {
    grid-template-columns: auto 1fr auto auto;
    gap: 1.25rem;
  }

  .menu-button {
    display: none;
  }

  .primary-navigation,
  .primary-navigation[hidden] {
    grid-column: auto;
    display: flex !important;
    flex-direction: row;
    justify-content: center;
    gap: 1.25rem;
    border: 0;
  }

  .primary-navigation a {
    border: 0;
  }

  .locale-switcher {
    grid-column: auto;
    flex-wrap: nowrap;
  }

  .theme-button {
    grid-column: auto;
    justify-self: auto;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}
}
```

- [x] **Step 9: Run static shell tests and verify green**

Run:

```bash
bin/rails test test/helpers/theme_helper_test.rb test/integration/public_shell_test.rb test/integration/public_localization_test.rb
```

Expected: 14 tests pass with 0 failures and 0 errors.

- [x] **Step 10: Compile CSS and commit the static shell**

Run:

```bash
bin/rails tailwindcss:build
```

Expected: command exits 0 and writes the generated Tailwind build without CSS syntax errors.

Commit:

```bash
git add app/helpers/application_helper.rb app/helpers/theme_helper.rb app/views/layouts/application.html.erb app/views/shared/_header.html.erb app/views/shared/_footer.html.erb app/assets/tailwind/application.css config/locales/en.yml config/locales/fr.yml config/locales/vi.yml test/helpers/theme_helper_test.rb test/integration/public_shell_test.rb
git commit -m "feat: build responsive public shell"
```

---

### Task 4: Add tested menu and persistent theme interactions

**Files:**

- Create: `test/application_system_test_case.rb`
- Create: `test/system/public_shell_test.rb`
- Create: `app/javascript/controllers/menu_controller.js`
- Create: `app/javascript/controllers/theme_controller.js`

**Interfaces:**

- Consumes: the header's `menu`/`theme` Stimulus data attributes, generated automatic Stimulus controller loading, CSS theme tokens, Capybara, Selenium, and `localStorage`.
- Produces: `menu#toggle`, Escape-to-close behavior, `theme#toggle`, `localStorage["portfolio-theme"]`, and synchronized `aria-expanded`/`aria-pressed` state.

- [x] **Step 1: Add the missing Rails system-test base and write failing browser tests**

The generated baseline includes Capybara and Selenium but omitted the system-test base. Create `test/application_system_test_case.rb`:

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
end
```

Create `test/system/public_shell_test.rb`:

```ruby
require "application_system_test_case"

class PublicShellTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [320, 800]

  test "locale choice survives navigation and a root reload" do
    visit localized_root_path(locale: "en")

    within ".locale-switcher" do
      click_link "Français"
    end
    assert_current_path localized_root_path(locale: "fr")

    find(".site-mark").click
    assert_current_path localized_root_path(locale: "fr")

    visit root_path
    assert_current_path localized_root_path(locale: "fr")
  end

  test "mobile menu is keyboard operable and the page does not overflow" do
    page.current_window.resize_to(320, 800)
    visit localized_root_path(locale: "en")

    assert_selector "#primary-navigation", visible: :hidden
    menu_button = find("button[aria-controls='primary-navigation']")
    menu_button.click

    assert_selector "#primary-navigation", visible: :visible
    assert_equal "true", menu_button["aria-expanded"]

    find("body").send_keys(:escape)
    assert_selector "#primary-navigation", visible: :hidden
    assert_equal "false", menu_button["aria-expanded"]
    assert page.active_element.matches_selector?(".menu-button")
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

    page.current_window.resize_to(1280, 900)
    visit localized_root_path(locale: "en")
    assert_selector "#primary-navigation", visible: :visible
    assert_selector ".menu-button", visible: :hidden
  end

  test "theme override is accessible and persists across pages" do
    visit localized_root_path(locale: "en")
    page.execute_script('localStorage.removeItem("portfolio-theme")')
    visit localized_root_path(locale: "en")

    assert_selector "[data-theme-target='toggle'][aria-pressed]"
    toggle = find("[data-theme-target='toggle']")
    assert_includes %w[true false], toggle["aria-pressed"]
    toggle.click

    selected_theme = page.evaluate_script('localStorage.getItem("portfolio-theme")')
    assert_includes %w[light dark], selected_theme
    assert_equal selected_theme, page.evaluate_script("document.documentElement.dataset.theme")

    visit localized_about_path(locale: "en")
    assert_equal selected_theme, page.evaluate_script("document.documentElement.dataset.theme")
    assert_equal((selected_theme == "dark").to_s, find("[data-theme-target='toggle']")["aria-pressed"])
  end
end
```

- [x] **Step 2: Run the system test and verify red**

Run:

```bash
bin/rails test:system test/system/public_shell_test.rb
```

Expected: FAIL because the mobile menu remains hidden and the theme control does not expose `aria-pressed` or persist a selection; it must not fail with a missing system-test base.

- [x] **Step 3: Implement the minimal mobile menu controller**

Create `app/javascript/controllers/menu_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "label", "panel"];
  static values = {
    openLabel: String,
    closeLabel: String,
  };

  connect() {
    this.close();
    this.handleKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.handleKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close();
  }

  open() {
    this.panelTarget.hidden = false;
    this.buttonTarget.setAttribute("aria-expanded", "true");
    this.labelTarget.textContent = this.closeLabelValue;
  }

  close() {
    this.panelTarget.hidden = true;
    this.buttonTarget.setAttribute("aria-expanded", "false");
    this.labelTarget.textContent = this.openLabelValue;
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close();
      this.buttonTarget.focus();
    }
  }
}
```

- [x] **Step 4: Implement the minimal persistent theme controller**

Create `app/javascript/controllers/theme_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "portfolio-theme";
const THEMES = ["light", "dark"];

export default class extends Controller {
  static targets = ["toggle"];
  static values = {
    lightLabel: String,
    darkLabel: String,
  };

  connect() {
    this.systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
    this.handleSystemChange = () => {
      if (!this.savedTheme) this.sync();
    };
    this.systemTheme.addEventListener("change", this.handleSystemChange);
    this.sync();
  }

  disconnect() {
    this.systemTheme.removeEventListener("change", this.handleSystemChange);
  }

  toggle() {
    const nextTheme = this.currentTheme === "dark" ? "light" : "dark";
    localStorage.setItem(STORAGE_KEY, nextTheme);
    document.documentElement.dataset.theme = nextTheme;
    this.sync();
  }

  get savedTheme() {
    const value = localStorage.getItem(STORAGE_KEY);
    return THEMES.includes(value) ? value : null;
  }

  get currentTheme() {
    return this.savedTheme || (this.systemTheme.matches ? "dark" : "light");
  }

  sync() {
    const dark = this.currentTheme === "dark";
    this.toggleTarget.setAttribute("aria-pressed", dark.toString());
    this.toggleTarget.setAttribute(
      "aria-label",
      dark ? this.lightLabelValue : this.darkLabelValue,
    );
    this.toggleTarget.textContent = dark
      ? this.lightLabelValue
      : this.darkLabelValue;
  }
}
```

Do not add manual controller registration: the generated `app/javascript/controllers/index.js` already calls `eagerLoadControllersFrom("controllers", application)`.

- [x] **Step 5: Run the focused system and request tests**

Run:

```bash
bin/rails test:system test/system/public_shell_test.rb
bin/rails test test/integration/public_localization_test.rb test/integration/public_shell_test.rb test/helpers/theme_helper_test.rb
```

Expected: the system file reports 3 tests with 0 failures and 0 errors; the request/helper command reports 14 tests with 0 failures and 0 errors.

- [x] **Step 6: Commit the interactions**

```bash
git add app/javascript/controllers/menu_controller.js app/javascript/controllers/theme_controller.js test/application_system_test_case.rb test/system/public_shell_test.rb
git commit -m "feat: add menu and theme interactions"
```

---

### Task 5: Verify and accept the phase boundary

**Files:**

- Verify only: all Phase 1 files
- Do not modify: approved spec, immutable parent plan, or `tmp/`

**Interfaces:**

- Consumes: Tasks 1–4.
- Produces: accepted and tagged `portfolio-v4-phase-1` foundation for Phase 2.

- [x] **Step 1: Run the complete automated acceptance suite**

Run:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
```

Expected: every command exits 0; both test suites report 0 failures and 0 errors; RuboCop reports no offenses.

- [x] **Step 2: Verify routes and version constraints**

Run:

```bash
bin/rails runner 'abort "wrong Ruby" unless RUBY_VERSION == "4.0.6"; abort "wrong Rails" unless Rails.gem_version.segments.first(2) == [8, 1]; puts "versions accepted"'
bin/rails routes | grep -E 'localized_(root|projects|blog|about|resume|contact)'
```

Expected: the first command prints `versions accepted`; the second lists all six route helpers with paths under `/:locale`.

- [x] **Step 3: Demonstrate HTTP locale precedence and unsupported-locale handling**

Start the app in one terminal:

```bash
bin/dev
```

Expected: Puma and the Tailwind watcher start without errors on `http://localhost:3000`.

In another terminal, run:

```bash
curl -sI http://localhost:3000/ | grep -i '^location:'
curl -sI -H 'Accept-Language: vi-VN,fr;q=0.8' http://localhost:3000/ | grep -i '^location:'
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/de/about
```

Expected: locations end in `/en` and `/vi`, in that order; the final command prints `404`.

- [x] **Step 4: Demonstrate all five server-selected accents**

Stop `bin/dev`, then run each command long enough to inspect the `<html data-accent>` value at `http://localhost:3000/en`:

```bash
SITE_ACCENT=brown bin/rails server
SITE_ACCENT=green bin/rails server
SITE_ACCENT=lime bin/rails server
SITE_ACCENT=orange bin/rails server
SITE_ACCENT=yellow bin/rails server
```

Expected: each run renders the matching allowlisted `data-accent`; running without `SITE_ACCENT` or with `SITE_ACCENT=purple` renders `data-accent="lime"`.

- [ ] **Step 5: Complete the manual responsive and accessibility check**

With `bin/dev` running, verify in a browser:

1. At 320 CSS pixels, the menu opens by touch/click, closes with Escape, returns focus to its button, and no horizontal scrollbar appears.
2. At 1280 CSS pixels, primary navigation remains visible and the menu button is hidden.
3. At 200% zoom, every navigation, locale, and theme action remains visible and operable.
4. Tab order follows site mark, menu/navigation, languages, theme, page content, and footer; every focused item has a visible accent outline.
5. With no `portfolio-theme` localStorage entry, changing OS/browser color preference changes the site mode.
6. After activating the theme button, navigation and reload retain the selected mode with no incorrect-theme flash.
7. Enabling reduced motion removes nonessential transition/animation duration.

Expected: all seven observations pass in light and dark modes.

- [x] **Step 6: Confirm scope and immutable inputs**

Run:

```bash
bundle exec ruby -e 'forbidden = %w[commonmarker rotp]; locked = File.read("Gemfile.lock"); abort "later-phase gem present" if forbidden.any? { |gem| locked.match?(/^    #{gem} /) }; puts "dependency scope accepted"'
git diff --exit-code -- docs/superpowers/specs/2026-09-02-portfolio-v4-design.md docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md tmp
git status --short
```

Expected: `dependency scope accepted`, then no diff output; `git status --short` is empty. If acceptance revealed a defect, fix only the responsible Phase 1 file, rerun the smallest failing check plus Step 1, and commit that focused correction before continuing.

- [ ] **Step 7: Tag the accepted phase**

```bash
git tag -a portfolio-v4-phase-1 -m "Accept portfolio v4 phase 1 foundation"
git show --no-patch --oneline portfolio-v4-phase-1
```

Expected: the tag resolves to the final accepted Phase 1 commit. Do not start Phase 2 until this tag exists and every acceptance check above passes.

## Phase 1 acceptance checklist

- [ ] Rails boots on Ruby 4.0.6 with a resolved Rails 8.1.x version, SQLite, Tailwind, Turbo, and Stimulus.
- [ ] `/` selects a valid locale in strict cookie → weighted `Accept-Language` → English order.
- [ ] `/en`, `/fr`, and `/vi` expose all six shell pages; unsupported locale segments return 404.
- [ ] Visiting a localized page saves that locale, and the site mark plus language switcher preserve an equivalent shell page.
- [ ] Fixed interface copy is complete in English, French, and Vietnamese with I18n fallback disabled.
- [ ] Semantic header, main, and footer markup works with keyboard and touch at 320px and desktop widths.
- [ ] The mobile menu synchronizes `hidden` and `aria-expanded`, closes on Escape, and returns focus.
- [ ] System color preference works without stored state; a light/dark override persists in `localStorage` and is applied before CSS.
- [ ] Brown, Green, Lime, Orange, and Yellow use the exact light/dark values from the approved spec; invalid selection falls back to Lime.
- [ ] Focus, touch-target, reduced-motion, no-gradient/no-shadow, line-length, and no-horizontal-overflow foundations are present.
- [ ] `bin/rails test`, `bin/rails test:system`, and `bin/rubocop` pass.
- [ ] The approved spec, parent plan, and `tmp/` are unchanged, and tag `portfolio-v4-phase-1` marks the accepted commit.
