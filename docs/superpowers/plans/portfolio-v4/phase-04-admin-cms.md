# Phase 4: Admin CMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the authenticated owner a mobile-first CMS for every shared and localized content record, uploads, stable editable slugs, locale tabs, site accent selection, and sanitized Markdown previews.

**Architecture:** Keep the Rails monolith server-rendered. Resource controllers accept one shared record plus nested `translations_attributes`; a small admin helper and two Stimulus controllers provide accessible locale tabs and server-backed preview without introducing a component library or JSON API. Existing Phase 2 domain validations and Phase 3 authentication remain the authority for content safety and access control.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Hotwire/Turbo Frames, Stimulus, Tailwind CSS, SQLite, Active Storage, Commonmarker, Minitest, Capybara

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

**Parent plan:** `docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md` — Phase 4's contract is immutable; this plan only expands it.

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
- Use Rails defaults and the standard library before adding dependencies. The only planned application gems beyond generated Rails defaults are `commonmarker` and `rotp`.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.
- In this agent environment, run repository executables through Ruby 4.0.6: `mise exec -- ruby bin/rails ...`, `mise exec -- ruby bin/importmap ...`, `mise exec -- ruby bin/rubocop`, and `mise exec -- ruby bin/brakeman ...`. Plain `bin/*` commands resolve to the system Ruby 2.6 and fail before Rails boots.

---

## Scope Boundary and Consumed Interfaces

The implementation branch must contain the accepted `portfolio-v4-phase-3` tag and start from a commit for which `git merge-base --is-ancestor portfolio-v4-phase-3 HEAD` succeeds. Phase 1 supplies Tailwind, Turbo, Stimulus, semantic theme/accent tokens, and responsive layouts. Phase 2 supplies these exact domain interfaces: `MarkdownRenderer.call(markdown) -> String`, nullable `Profile.current`, nullable `Resume.current`, `Project#cover_image`, `Project#gallery_images`, `Post#cover_image`, `Profile#portrait`, `ResumeTranslation#pdf`, `Project#tags`, `Post#tags`, and translation associations named `translations`. It also supplies attachment MIME-type/filename-extension/size validations and localized slug uniqueness. Phase 3 supplies the unchanged `Admin::BaseController#require_admin!`, `Current.admin_user`, the protected admin layout, `sign_in_as_admin`/`sign_out_admin` for request tests, and `sign_in_owner` for system tests.

Use the Phase 2 column names below; do not add a corrective schema migration in this phase:

- `Project`: `role`, `started_on`, `ended_on`, `live_url`, `source_url`, `featured_position`.
- `ProjectTranslation`: `locale`, `title`, `slug`, `summary`, `body_markdown`, `body_html`, `state`, `scheduled_at`, `published_at`.
- `PostTranslation`: `locale`, `title`, `slug`, `excerpt`, `body_markdown`, `body_html`, `state`, `scheduled_at`, `published_at`.
- `TagTranslation`: `locale`, `name`, `slug`.
- `Profile`: `public_contact_email`, `social_links`, `accent`.
- `ProfileTranslation`: `locale`, `display_name`, `headline`, `introduction`, `biography_markdown`, `biography_html`, `availability_label`.
- `Resume`: `updated_on`.
- `ResumeTranslation`: `locale`, `title`, `description` and attached `pdf`.

`social_links` remains the Phase 2 JSON object. The admin form edits the fixed keys `github`, `linkedin`, and `website`; the controller compacts blank values before assignment. Do not add publication transition buttons, recurring jobs, contact inbox behavior, SEO, or deployment work here; those belong to Phases 5–8. In this phase state badges are read-only and new project/post translations remain drafts.

## File Map

**Create**

- `app/helpers/admin/content_helper.rb` — locale ordering, completion/state badges, and deterministic preview frame IDs.
- `app/javascript/controllers/locale_tabs_controller.js` — accessible tabs with click and arrow-key behavior.
- `app/javascript/controllers/markdown_preview_controller.js` — posts Markdown to the authenticated endpoint and replaces one Turbo Frame.
- `app/controllers/admin/markdown_previews_controller.rb` and `app/views/admin/markdown_previews/create.html.erb` — sanitized preview response.
- `app/controllers/admin/projects_controller.rb`, `posts_controller.rb`, `tags_controller.rb`, `profiles_controller.rb`, `resumes_controller.rb` — CMS endpoints.
- `app/views/admin/shared/_errors.html.erb`, `_locale_tabs.html.erb`, `_translation_controls.html.erb`, `_markdown_editor.html.erb` — shared form UI.
- Resource views under `app/views/admin/projects/`, `posts/`, `tags/`, `profiles/`, and `resumes/` listed in their tasks.
- `test/helpers/admin/content_helper_test.rb`, `test/requests/admin/markdown_previews_test.rb`, resource request tests, `test/requests/admin/cms_authorization_test.rb`, and `test/system/admin_manages_content_test.rb`.
- Upload fixture `test/fixtures/files/resume.pdf`; image tests reuse the checked-in `public/icon.png`, and invalid-upload tests wrap the checked-in `Gemfile` as `text/plain`.

**Modify**

- `config/routes.rb` — authenticated admin resource and preview routes.
- `app/controllers/admin/base_controller.rb` — build missing locale records and strip attempted locale changes from persisted nested translations.
- `app/controllers/admin/dashboard_controller.rb` and `app/views/admin/dashboard/show.html.erb` — actionable content counts and links.
- `app/views/layouts/admin.html.erb` — mobile navigation to all CMS sections.
- `app/models/project.rb`, `post.rb`, `tag.rb`, `profile.rb`, `resume.rb` — nested translation writes.
- `app/models/project_translation.rb`, `post_translation.rb`, `tag_translation.rb` — create-only slug generation and explicit slug-format validation.
- `app/assets/tailwind/application.css` — add the two admin component classes plus textarea and checkbox/radio form primitives required by Phase 4.
- Existing model files only to add nested-attribute declarations required by the forms; Phase 3 already provides request and system authentication helpers.

## Shared Parameter Contracts

All translation forms submit an indexed hash, not locale-named top-level keys:

```ruby
{
  translations_attributes: {
    "0" => { id: "12", locale: "en", title: "Title", slug: "title", body_markdown: "Text", _destroy: "0" },
    "1" => { id: "13", locale: "fr", title: "Titre", slug: "titre", body_markdown: "Texte", _destroy: "0" },
    "2" => { locale: "vi", title: "", slug: "", body_markdown: "", _destroy: "0" }
  }
}
```

Locale is accepted only when creating a missing nested record. Before assignment, `Admin::BaseController#protect_translation_locales(attributes)` removes `locale` from every nested translation hash containing an `id`; nested association ownership prevents moving a translation between parent records, and `(parent_id, locale)` uniqueness prevents duplicates. English `_destroy` is never rendered; optional translations expose it only after persistence. `state`, `scheduled_at`, `published_at`, rendered HTML fields, and Active Storage metadata are never permitted. Controllers use Rails 8.1 `params.expect`; collection-style nested attributes use the double-array filter form, for example `translations_attributes: [ %i[id locale title slug summary body_markdown _destroy] ]`.

---

### Task 1: Protected CMS Shell and Dashboard

**Files:**

- Modify: `config/routes.rb`
- Modify: `app/controllers/admin/base_controller.rb`
- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Modify: `app/views/layouts/admin.html.erb`
- Modify: `app/assets/tailwind/application.css`
- Create: `test/requests/admin/dashboard_test.rb`

**Interfaces:**

- Consumes: `Admin::BaseController#require_admin!`, `Current.admin_user`, `Profile.current`, `Resume.current`.
- Produces: named admin routes, `Admin::BaseController#prepare_translations(record)`, and `Admin::BaseController#protect_translation_locales(attributes) -> ActionController::Parameters`.

- [ ] **Step 1: Write the failing dashboard request test**

```ruby
# test/requests/admin/dashboard_test.rb
require "test_helper"

class Admin::DashboardTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  test "shows mobile friendly links and content counts" do
    project = Project.new(role: "Engineer")
    project.translations.build(locale: "en", title: "One", slug: "one", summary: "Summary", body_markdown: "Body")
    project.save!

    post = Post.new
    post.translations.build(locale: "en", title: "Two", slug: "two", excerpt: "Excerpt", body_markdown: "Body")
    post.save!

    tag = Tag.new
    tag.translations.build(locale: "en", name: "Ruby", slug: "ruby")
    tag.save!

    get admin_root_path

    assert_response :success
    assert_select "nav[aria-label='Admin']"
    assert_select "a[href='#{admin_projects_path}']", text: /Projects/
    assert_select "a[href='#{admin_posts_path}']", text: /Posts/
    assert_select "a[href='#{admin_tags_path}']", text: /Tags/
    assert_select "a[href='#{edit_admin_profile_path}']", text: /Profile/
    assert_select "a[href='#{edit_admin_resume_path}']", text: /Résumé/
    assert_select "[data-testid='project-count']", text: "1"
    assert_select "[data-testid='post-count']", text: "1"
    assert_select "[data-testid='tag-count']", text: "1"
  end

  test "redirects an unauthenticated request before loading content" do
    sign_out_admin
    get admin_projects_path
    assert_redirected_to new_admin_session_path
  end
end
```

- [ ] **Step 2: Run the test and verify the missing routes fail**

Run: `mise exec -- ruby bin/rails test test/requests/admin/dashboard_test.rb`

Expected: FAIL because `admin_projects_path`, `edit_admin_profile_path`, and other CMS routes do not exist.

- [ ] **Step 3: Add exact routes**

Inside the existing `namespace :admin` block in `config/routes.rb`, retain the Phase 3 session/TOTP routes and use:

```ruby
root "dashboard#show"
resources :projects do
  delete :cover_image, on: :member
  delete "gallery_images/:attachment_id", action: :gallery_image, on: :member, as: :gallery_image
end
resources :posts do
  delete :cover_image, on: :member
end
resources :tags, except: :show
resource :profile, only: %i[edit update] do
  delete :portrait
end
resource :resume, only: %i[edit update] do
  delete "translations/:translation_id/pdf", action: :pdf, as: :translation_pdf
end
resource :markdown_preview, only: :create
```

Add this protected form utility to `Admin::BaseController`:

```ruby
protected

ADMIN_LOCALES = %w[en fr vi].freeze

def prepare_translations(record)
  existing = record.translations.map(&:locale)
  (ADMIN_LOCALES - existing).each { |locale| record.translations.build(locale:) }
end

def protect_translation_locales(attributes)
  attributes[:translations_attributes]&.each_value do |translation|
    translation.delete(:locale) if translation[:id].present?
  end
  attributes
end
```

Implement `DashboardController#show` without loading rows:

```ruby
def show
  @project_count = Project.count
  @post_count = Post.count
  @tag_count = Tag.count
end
```

Render three count cards and quick links in `show.html.erb`. In `layouts/admin.html.erb`, use a `<nav aria-label="Admin">` whose links are Dashboard, Projects, Posts, Tags, Profile, and Résumé. Base layout is one column; add `md:grid md:grid-cols-[14rem_1fr]`. Do not use a table or hide actions on small screens. Add these component classes to the existing Tailwind component layer:

```css
@layer components {
  .admin-card {
    @apply rounded-lg border border-current/20 p-4;
  }
  .admin-action {
    @apply inline-flex min-h-11 items-center justify-center rounded-md border border-current px-4 py-2 font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2;
  }
}
```

Also extend the existing base form rules so `textarea` shares the full-width `input, select` styling. Reset `input[type="checkbox"]` and `input[type="radio"]` to `width: auto` and `min-height: auto`; their visible `<label>` wrappers provide `min-h-11` touch targets. This prevents the existing global `input { width: 100% }` rule from stretching Phase 4 checkboxes and radios across the form.

- [ ] **Step 4: Run the dashboard and authorization tests**

Run: `mise exec -- ruby bin/rails test test/requests/admin/dashboard_test.rb test/requests/admin/authentication_test.rb`

Expected: PASS; the unauthenticated CMS request follows Phase 3's login redirect.

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/admin/base_controller.rb app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb app/views/layouts/admin.html.erb app/assets/tailwind/application.css test/requests/admin/dashboard_test.rb
git commit -m "feat(admin): add protected CMS navigation"
```

---

### Task 2: Locale Tabs, Nested Translation Writes, and Stable Slugs

**Files:**

- Create: `app/helpers/admin/content_helper.rb`
- Create: `app/views/admin/shared/_errors.html.erb`
- Create: `app/views/admin/shared/_locale_tabs.html.erb`
- Create: `app/views/admin/shared/_translation_controls.html.erb`
- Create: `app/javascript/controllers/locale_tabs_controller.js`
- Modify: `app/models/project.rb`, `post.rb`, `tag.rb`, `profile.rb`, `resume.rb`
- Modify: `app/models/project_translation.rb`, `post_translation.rb`, `tag_translation.rb`
- Create: `test/helpers/admin/content_helper_test.rb`
- Create: `test/models/project_translation_test.rb`, `post_translation_test.rb`, `tag_translation_test.rb`

**Interfaces:**

- Consumes: every content model's `translations` association and Phase 2 localized uniqueness validations.
- Produces: `accepts_nested_attributes_for :translations`, `Admin::ContentHelper#translation_complete?`, `#translation_state_label`, and create-only slug generation.

- [ ] **Step 1: Write failing helper and model tests**

```ruby
# test/helpers/admin/content_helper_test.rb
require "test_helper"

class Admin::ContentHelperTest < ActionView::TestCase
  include Admin::ContentHelper

  test "reports completion from every required authored field" do
    assert translation_complete?(ProjectTranslation.new(title: "Work", summary: "Summary", body_markdown: "Body"))
    assert translation_complete?(TagTranslation.new(name: "Rails"))
    assert translation_complete?(ProfileTranslation.new(
      display_name: "Owner", headline: "Headline", introduction: "Introduction",
      biography_markdown: "Biography", availability_label: "Available"
    ))
    refute translation_complete?(PostTranslation.new(title: "Post", excerpt: "", body_markdown: "Body"))
  end

  test "uses a deterministic locale specific preview frame id" do
    translation = ProjectTranslation.new(locale: "vi")
    assert_equal "project_vi_markdown_preview", markdown_preview_frame_id(translation)
  end
end
```

Create `test/models/project_translation_test.rb`:

```ruby
require "test_helper"

class ProjectTranslationTest < ActiveSupport::TestCase
  test "generates slug once and does not change it when title changes" do
    project = Project.create!(role: "Engineer", translations_attributes: {
      "0" => { locale: "en", title: "First Title", summary: "Summary", body_markdown: "Body" }
    })
    translation = project.translations.find_by!(locale: "en")
    assert_equal "first-title", translation.slug

    translation.update!(title: "Renamed Title")
    assert_equal "first-title", translation.reload.slug

    translation.update!(slug: "chosen-slug")
    assert_equal "chosen-slug", translation.reload.slug

    translation.slug = "Not/A/Slug"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
```

Create `test/models/post_translation_test.rb`:

```ruby
require "test_helper"

class PostTranslationTest < ActiveSupport::TestCase
  test "generates slug once and does not change it when title changes" do
    post = Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "First Post", excerpt: "Excerpt", body_markdown: "Body" }
    })
    translation = post.translations.find_by!(locale: "en")
    assert_equal "first-post", translation.slug

    translation.update!(title: "Renamed Post")
    assert_equal "first-post", translation.reload.slug

    translation.update!(slug: "chosen-post")
    assert_equal "chosen-post", translation.reload.slug

    translation.slug = "two words"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
```

Create `test/models/tag_translation_test.rb`:

```ruby
require "test_helper"

class TagTranslationTest < ActiveSupport::TestCase
  test "generates slug once and does not change it when name changes" do
    tag = Tag.create!(translations_attributes: {
      "0" => { locale: "en", name: "Ruby on Rails" }
    })
    translation = tag.translations.find_by!(locale: "en")
    assert_equal "ruby-on-rails", translation.slug

    translation.update!(name: "Rails")
    assert_equal "ruby-on-rails", translation.reload.slug

    translation.update!(slug: "rails-framework")
    assert_equal "rails-framework", translation.reload.slug

    translation.slug = "rails--framework"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `mise exec -- ruby bin/rails test test/helpers/admin/content_helper_test.rb test/models/project_translation_test.rb test/models/post_translation_test.rb test/models/tag_translation_test.rb`

Expected: FAIL because the helper and create-only callbacks are absent.

- [ ] **Step 3: Add the minimal shared form interfaces**

Use this helper:

```ruby
module Admin::ContentHelper
  LOCALE_NAMES = { "en" => "English", "fr" => "French", "vi" => "Vietnamese" }.freeze
  REQUIRED_TRANSLATION_FIELDS = {
    ProjectTranslation => %i[title summary body_markdown],
    PostTranslation => %i[title excerpt body_markdown],
    TagTranslation => %i[name],
    ProfileTranslation => %i[display_name headline introduction biography_markdown availability_label],
    ResumeTranslation => %i[title description]
  }.freeze

  def translation_complete?(translation)
    REQUIRED_TRANSLATION_FIELDS.fetch(translation.class)
      .all? { |field| translation.public_send(field).present? }
  end

  def translation_state_label(translation)
    translation.respond_to?(:state) ? translation.state.humanize : nil
  end

  def markdown_preview_frame_id(translation)
    owner = translation.model_name.element.delete_suffix("_translation")
    "#{owner}_#{translation.locale}_markdown_preview"
  end
end
```

Each shared model gets nested writes. Use its own identifying/content fields so a blank optional tab does not create a row. For `Project`:

```ruby
accepts_nested_attributes_for :translations, allow_destroy: true,
  reject_if: ->(attributes) {
    attributes["locale"] != "en" && attributes["id"].blank? &&
      attributes.values_at("title", "slug", "summary", "body_markdown").all?(&:blank?)
  }
```

Add the corresponding explicit declarations; keep Phase 2's English-required validation authoritative:

```ruby
# Post
accepts_nested_attributes_for :translations, allow_destroy: true,
  reject_if: ->(attributes) {
    attributes["locale"] != "en" && attributes["id"].blank? &&
      attributes.values_at("title", "slug", "excerpt", "body_markdown").all?(&:blank?)
  }

# Tag
accepts_nested_attributes_for :translations, allow_destroy: true,
  reject_if: ->(attributes) {
    attributes["locale"] != "en" && attributes["id"].blank? &&
      attributes.values_at("name", "slug").all?(&:blank?)
  }

# Profile
accepts_nested_attributes_for :translations, allow_destroy: true,
  reject_if: ->(attributes) {
    attributes["locale"] != "en" && attributes["id"].blank? &&
      attributes.values_at(
        "display_name", "headline", "introduction", "biography_markdown", "availability_label"
      ).all?(&:blank?)
  }

# Resume
accepts_nested_attributes_for :translations, allow_destroy: true,
  reject_if: ->(attributes) {
    attributes["locale"] != "en" && attributes["id"].blank? &&
      attributes.values_at("title", "description").all?(&:blank?)
  }
```

In each slugged translation model add:

```ruby
before_validation :set_initial_slug, on: :create

private

def set_initial_slug
  self.slug = title.to_s.parameterize if slug.blank?
end
```

For `TagTranslation`, parameterize `name` instead of `title`.

In all three slugged translation models, keep the existing presence and locale-scoped uniqueness validations and add:

```ruby
validates :slug, format: {
  with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
  message: "must use lowercase letters, numbers, and single hyphens"
}
```

`_errors.html.erb` renders `record.errors.full_messages` in an alert. `_translation_controls.html.erb` renders a hidden `id` for persisted records and a hidden `locale` only for new records, a completion badge, a read-only state badge when present, and an optional `_destroy` checkbox only when locale is not `en` and the translation is persisted.

`_locale_tabs.html.erb` receives `form:`, `record:`, and `fields_partial:`. Resolve and render translations explicitly in `en`, `fr`, `vi` order. Each tab is `<button type="button">` with a unique `id`, `role="tab"`, matching `aria-controls`, `aria-selected="true"` only for English, `tabindex="0"` only for English, a 44px minimum height, and the completion/state badges. Each corresponding panel has a unique `id`, `role="tabpanel"`, and matching `aria-labelledby`. Render every panel without `hidden` in server HTML so every locale remains editable without JavaScript; `connect()` immediately calls `select(0)` and hides inactive panels when Stimulus is available. Within each panel use `form.fields_for :translations, translation` and render `fields_partial` with local `form:`.

Implement the tab controller exactly as keyboard-accessible progressive enhancement:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];

  connect() {
    this.select(
      this.tabTargets.findIndex(
        (tab) => tab.getAttribute("aria-selected") === "true",
      ),
    );
  }

  choose(event) {
    this.select(this.tabTargets.indexOf(event.currentTarget));
  }

  move(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const current = this.tabTargets.indexOf(event.currentTarget);
    const index =
      event.key === "Home"
        ? 0
        : event.key === "End"
          ? this.tabTargets.length - 1
          : (current +
              (event.key === "ArrowRight" ? 1 : -1) +
              this.tabTargets.length) %
            this.tabTargets.length;
    this.select(index);
    this.tabTargets[index].focus();
  }

  select(index) {
    this.tabTargets.forEach((tab, position) => {
      const selected = position === index;
      tab.setAttribute("aria-selected", selected.toString());
      tab.tabIndex = selected ? 0 : -1;
      this.panelTargets[position].hidden = !selected;
    });
  }
}
```

- [ ] **Step 4: Run focused tests and the JavaScript import smoke test**

Run:

```bash
mise exec -- ruby bin/rails test test/helpers/admin/content_helper_test.rb test/models/project_translation_test.rb test/models/post_translation_test.rb test/models/tag_translation_test.rb
mise exec -- ruby bin/importmap audit
```

Expected: PASS; the Importmap audit reports no vulnerable packages.

- [ ] **Step 5: Commit**

```bash
git add app/helpers/admin/content_helper.rb app/views/admin/shared app/javascript/controllers/locale_tabs_controller.js app/models/project.rb app/models/post.rb app/models/tag.rb app/models/profile.rb app/models/resume.rb app/models/project_translation.rb app/models/post_translation.rb app/models/tag_translation.rb test/helpers/admin/content_helper_test.rb test/models/project_translation_test.rb test/models/post_translation_test.rb test/models/tag_translation_test.rb
git commit -m "feat(admin): add localized nested forms"
```

---

### Task 3: Authenticated Turbo Frame Markdown Preview

**Files:**

- Create: `app/controllers/admin/markdown_previews_controller.rb`
- Create: `app/views/admin/markdown_previews/create.html.erb`
- Create: `app/views/admin/shared/_markdown_editor.html.erb`
- Create: `app/javascript/controllers/markdown_preview_controller.js`
- Create: `test/requests/admin/markdown_previews_test.rb`

**Interfaces:**

- Consumes: `MarkdownRenderer.call(markdown) -> String`, Phase 3 admin authentication, Turbo.
- Produces: `POST /admin/markdown_preview` accepting `preview[markdown]` and `preview[frame_id]`, returning one matching `<turbo-frame>`, plus `admin/shared/_markdown_editor.html.erb` accepting locals `form:`, `attribute:`, and `label:`.

- [ ] **Step 1: Write the failing request tests**

````ruby
require "test_helper"

class Admin::MarkdownPreviewsTest < ActionDispatch::IntegrationTest
  test "requires the fully authenticated owner" do
    post admin_markdown_preview_path, params: { preview: { markdown: "# Draft", frame_id: "post_en_markdown_preview" } }
    assert_redirected_to new_admin_session_path
  end

  test "renders sanitized markdown in the requested turbo frame" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: {
      preview: { markdown: "# Safe\n\n<script>alert(1)</script>\n\n```ruby\nputs :ok\n```", frame_id: "post_en_markdown_preview" }
    }, headers: { "Turbo-Frame" => "post_en_markdown_preview" }

    assert_response :success
    assert_select "turbo-frame#post_en_markdown_preview[data-markdown-preview-target='frame']" do
      assert_select "h1", text: "Safe"
      assert_select "pre code", text: /puts :ok/
      assert_select "script", count: 0
    end
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "rejects a frame id outside the admin naming contract" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: { preview: { markdown: "Text", frame_id: "bad id<script>" } }
    assert_response :unprocessable_entity
  end

  test "rejects a malformed parameter scope without raising" do
    sign_in_as_admin
    post admin_markdown_preview_path, params: { preview: "not-an-object" }
    assert_response :bad_request
  end
end
````

- [ ] **Step 2: Run and verify the controller is missing**

Run: `mise exec -- ruby bin/rails test test/requests/admin/markdown_previews_test.rb`

Expected: FAIL with `uninitialized constant Admin::MarkdownPreviewsController`.

- [ ] **Step 3: Implement the authenticated server preview and thin Stimulus adapter**

```ruby
class Admin::MarkdownPreviewsController < Admin::BaseController
  FRAME_ID = /\A(?:project|post|profile)_(?:en|fr|vi)_markdown_preview\z/

  def create
    values = params.expect(preview: %i[markdown frame_id])
    frame_id = values[:frame_id].to_s
    return head :unprocessable_entity unless FRAME_ID.match?(frame_id)

    @frame_id = frame_id
    @html = MarkdownRenderer.call(values[:markdown].to_s)
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
```

```erb
<%= turbo_frame_tag @frame_id, data: { markdown_preview_target: "frame" } do %>
  <article class="rich-text"><%= sanitize @html %></article>
<% end %>
```

The view reuses the public `.rich-text` styles and Rails' `sanitize` helper. Although `MarkdownRenderer` already sanitizes output, keeping the render boundary safe avoids introducing an `html_safe` exception and keeps Brakeman's contract explicit. The response repeats the Stimulus frame target so a second preview works after `outerHTML` replacement.

Create one editor partial used by project, post, and profile translation forms:

```erb
<% frame_id = markdown_preview_frame_id(form.object) %>
<div data-controller="markdown-preview"
     data-markdown-preview-url-value="<%= admin_markdown_preview_path %>"
     data-markdown-preview-frame-id-value="<%= frame_id %>">
  <%= form.label attribute, label %>
  <%= form.text_area attribute, rows: 18, data: { markdown_preview_target: "source" } %>
  <button type="button" class="admin-action" data-action="markdown-preview#render">Preview</button>
  <%= turbo_frame_tag frame_id, data: { markdown_preview_target: "frame" } do %>
    <p>Preview appears here.</p>
  <% end %>
</div>
```

Call it with locals `form:`, `attribute:` (`:body_markdown` or `:biography_markdown`), and the visible `label:`. This keeps the frame lifecycle identical across all three resources.

The Stimulus controller sends CSRF-protected form data and replaces only the returned frame:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source", "frame"];
  static values = { url: String, frameId: String };

  async render(event) {
    event.preventDefault();
    const body = new FormData();
    body.append("preview[markdown]", this.sourceTarget.value);
    body.append("preview[frame_id]", this.frameIdValue);
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: {
          Accept: "text/html",
          "Turbo-Frame": this.frameIdValue,
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
            .content,
        },
      });
      if (!response.ok) throw new Error("Preview request failed");
      this.frameTarget.outerHTML = await response.text();
    } catch (_error) {
      this.frameTarget.innerHTML = '<p role="status">Preview unavailable. Try again.</p>';
    }
  }
}
```

There is no public or shareable preview token.

- [ ] **Step 4: Run the preview tests**

Run: `mise exec -- ruby bin/rails test test/requests/admin/markdown_previews_test.rb test/models/markdown_renderer_test.rb`

Expected: PASS, including sanitization inherited from Phase 2.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/markdown_previews_controller.rb app/views/admin/markdown_previews/create.html.erb app/views/admin/shared/_markdown_editor.html.erb app/javascript/controllers/markdown_preview_controller.js test/requests/admin/markdown_previews_test.rb
git commit -m "feat(admin): add authenticated Markdown previews"
```

---

### Task 4: Project CRUD, Tags, and Shared Image Management

**Files:**

- Create: `app/controllers/admin/projects_controller.rb`
- Create: `app/views/admin/projects/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/projects_test.rb`
- Reuse: `public/icon.png` for valid images and `Gemfile` for an invalid upload.

**Interfaces:**

- Consumes: nested translations, `Project#tags`, `cover_image`, `gallery_images`, attachment validations, locale tabs, Markdown preview.
- Produces: full project CRUD and explicit cover/gallery purge routes.

- [ ] **Step 1: Write failing request tests for create, update, validation preservation, and removal**

The test file wraps `public/icon.png` with `Rack::Test::UploadedFile` and covers these exact requests:

```ruby
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
          featured_position: "1", tag_ids: [@tag.id],
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
    assert_equal [@tag.id], project.tag_ids
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

  test "purges only an owned gallery attachment" do
    project = create_project
    project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "one.png", content_type: "image/png")
    attachment = project.gallery_images.first
    delete gallery_image_admin_project_path(project, attachment_id: attachment.id)
    assert_redirected_to edit_admin_project_path(project)
    refute ActiveStorage::Attachment.exists?(attachment.id)
  end

  test "appends gallery uploads without replacing existing images" do
    project = create_project
    project.gallery_images.attach(io: Rails.root.join("public/icon.png").open, filename: "one.png", content_type: "image/png")

    patch admin_project_path(project), params: { project: {
      role: project.role,
      gallery_images: [image_upload]
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

  def create_project
    Project.create!(role: "Engineer", translations_attributes: {
      "0" => { locale: "en", title: "Existing Project", slug: "existing-project", summary: "Summary", body_markdown: "Body" }
    })
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/projects_test.rb`

Expected: FAIL because `Admin::ProjectsController` and views are absent.

- [ ] **Step 3: Implement the controller with an explicit strong-parameter boundary**

```ruby
class Admin::ProjectsController < Admin::BaseController
  before_action :set_project, only: %i[edit update destroy cover_image gallery_image]

  def index
    @projects = Project.includes(:translations, :tags).order(created_at: :desc)
  end

  def new
    @project = Project.new
    prepare_translations(@project)
  end

  def create
    @project = Project.new(protect_translation_locales(project_params))
    if @project.save
      redirect_to edit_admin_project_path(@project), notice: "Project created.", status: :see_other
    else
      prepare_translations(@project)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@project)
  end

  def update
    attributes = protect_translation_locales(project_params)
    gallery_images = attributes.delete(:gallery_images)
    @project.assign_attributes(attributes)
    @project.gallery_images.attach(gallery_images) if gallery_images.present?

    if @project.save
      redirect_to edit_admin_project_path(@project), notice: "Project saved.", status: :see_other
    else
      prepare_translations(@project)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to admin_projects_path, notice: "Project deleted.", status: :see_other
  end

  def cover_image
    @project.cover_image.purge
    redirect_to edit_admin_project_path(@project), notice: "Cover image removed.", status: :see_other
  end

  def gallery_image
    @project.gallery_images.attachments.find(params[:attachment_id]).purge
    redirect_to edit_admin_project_path(@project), notice: "Gallery image removed.", status: :see_other
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.expect(project: [
      :role, :started_on, :ended_on, :live_url, :source_url, :featured_position, :cover_image,
      {
        gallery_images: [], tag_ids: [],
        translations_attributes: [ %i[id locale title slug summary body_markdown _destroy] ]
      }
    ])
  end
end
```

The scoped `attachments.find` is required: it prevents deleting another record's blob by ID.

- [ ] **Step 4: Build all project views**

`index.html.erb` uses record cards, not a narrow table. Each card shows available locale/state badges and Edit/Delete actions. Delete uses `data: { turbo_method: :delete, turbo_confirm: "Delete this project and all translations?" }`.

`new.html.erb` and `edit.html.erb` render `_form`. `_form.html.erb` uses `form_with model: [:admin, project]`, renders shared errors, shared metadata fields, `collection_check_boxes :tag_ids, Tag.includes(:translations).order(:id), :id, ->(tag) { tag.translations.find { |item| item.locale == "en" }&.name || "Tag ##{tag.id}" }`, `file_field :cover_image, accept: "image/png,image/jpeg,image/webp"`, and `file_field :gallery_images, multiple: true, include_hidden: false, accept: "image/png,image/jpeg,image/webp"`. The controller appends these uploads; it never relies on `has_many_attached` assignment, which would replace the existing gallery. Existing attachment removal links use the named DELETE routes and explicit confirmations.

`_translation_fields.html.erb` renders hidden controls, title, editable slug with help text “Generated from the title when first saved; later title changes do not change it,” summary, and the shared Markdown editor:

```erb
<%= render "admin/shared/markdown_editor",
  form: form, attribute: :body_markdown, label: "Body (Markdown)" %>
```

Every input has a visible label; actions have `min-h-11`; form groups stack at the base breakpoint and use two columns only at `md:`. Render entered values from the bound invalid object, never from a reload.

- [ ] **Step 5: Run project tests and manually inspect phone layout**

Run: `mise exec -- ruby bin/rails test test/requests/admin/projects_test.rb test/models/project_translation_test.rb test/models/public_content_test.rb`

Run: `mise exec -- ruby bin/rails server`, sign in, open `/admin/projects/new` at 320×568, and verify no horizontal scroll, each locale tab/action is touch reachable, invalid values survive, preview updates only its locale, and image removal asks for confirmation.

Expected: all automated tests PASS and the manual checks succeed.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/projects_controller.rb app/views/admin/projects test/requests/admin/projects_test.rb
git commit -m "feat(admin): manage projects and images"
```

---

### Task 5: Post CRUD and Cover Images

**Files:**

- Create: `app/controllers/admin/posts_controller.rb`
- Create: `app/views/admin/posts/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/posts_test.rb`

**Interfaces:**

- Consumes: post nested translations, tags, cover attachment validation, shared tabs, and preview endpoint.
- Produces: complete post CRUD and cover purge.

- [ ] **Step 1: Write the failing post request tests**

Create request tests proving: unauthenticated access redirects; create persists English and Vietnamese while rejecting a blank French tab; selected tags and an image persist; invalid MIME type returns 422 with title/body still in the response; title-only update leaves the old slug; explicitly edited slug persists; a persisted French translation submitted with `locale: "vi"` remains French; a scalar `post` scope returns 400; `DELETE /admin/posts/:id/cover_image` purges the post's cover; and destroy removes the post with a 303 redirect.

Use this create payload in the test:

```ruby
post admin_posts_path, params: { post: {
  tag_ids: [@tag.id],
  cover_image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"),
  translations_attributes: {
    "0" => { locale: "en", title: "A careful post", slug: "", excerpt: "English excerpt", body_markdown: "# English" },
    "1" => { locale: "fr", title: "", slug: "", excerpt: "", body_markdown: "" },
    "2" => { locale: "vi", title: "Bài viết", slug: "bai-viet", excerpt: "Tóm tắt", body_markdown: "# Tiếng Việt" }
  }
} }
```

Assert `PostTranslation.count` changes by 2, its states are both `draft`, and the generated English slug is `a-careful-post`.

- [ ] **Step 2: Run and verify failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/posts_test.rb`

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement post CRUD**

Use this complete controller:

```ruby
class Admin::PostsController < Admin::BaseController
  before_action :set_post, only: %i[edit update destroy cover_image]

  def index
    @posts = Post.includes(:translations).order(created_at: :desc)
  end

  def new
    @post = Post.new
    prepare_translations(@post)
  end

  def create
    @post = Post.new(protect_translation_locales(post_params))
    if @post.save
      redirect_to edit_admin_post_path(@post), notice: "Post created.", status: :see_other
    else
      prepare_translations(@post)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@post)
  end

  def update
    if @post.update(protect_translation_locales(post_params))
      redirect_to edit_admin_post_path(@post), notice: "Post saved.", status: :see_other
    else
      prepare_translations(@post)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy!
    redirect_to admin_posts_path, notice: "Post deleted.", status: :see_other
  end

  def cover_image
    @post.cover_image.purge
    redirect_to edit_admin_post_path(@post), notice: "Cover image removed.", status: :see_other
  end

  private

  def set_post = @post = Post.find(params[:id])

  def post_params
    params.expect(post: [
      :cover_image,
      { tag_ids: [], translations_attributes: [ %i[id locale title slug excerpt body_markdown _destroy] ] }
    ])
  end
end
```

Build card-based index/new/edit/form views. The translation fields are title, slug, excerpt, and `<%= render "admin/shared/markdown_editor", form: form, attribute: :body_markdown, label: "Body (Markdown)" %>`. The cover input accepts PNG, JPEG, and WebP. Load tag choices with `Tag.includes(:translations).order(:id)` and label them from their English translation. Delete and cover removal use their named DELETE routes with explicit Turbo confirmations.

- [ ] **Step 4: Run focused tests**

Run: `mise exec -- ruby bin/rails test test/requests/admin/posts_test.rb test/models/post_translation_test.rb test/models/public_content_test.rb test/requests/admin/markdown_previews_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/posts_controller.rb app/views/admin/posts test/requests/admin/posts_test.rb
git commit -m "feat(admin): manage posts and cover images"
```

---

### Task 6: Localized Tag CRUD

**Files:**

- Create: `app/controllers/admin/tags_controller.rb`
- Create: `app/views/admin/tags/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/tags_test.rb`

**Interfaces:**

- Consumes: `Tag#translations`, localized slug uniqueness, and taggings dependent-destroy behavior from Phase 2.
- Produces: localized tag CRUD used immediately by project/post selectors.

- [ ] **Step 1: Write failing tests**

Test that create with English/French and blank Vietnamese produces exactly two translations; blank English returns 422 with the French value preserved; duplicate French slug returns 422; renaming a tag does not rewrite its slug; an explicit slug update works; a persisted French translation submitted as Vietnamese remains French; a scalar `tag` scope returns 400; destroy removes the tag and its taggings but not associated projects/posts; and unauthenticated index redirects.

Use this exact valid payload:

```ruby
{ tag: { translations_attributes: {
  "0" => { locale: "en", name: "Web performance", slug: "" },
  "1" => { locale: "fr", name: "Performance web", slug: "performance-web" },
  "2" => { locale: "vi", name: "", slug: "" }
} } }
```

- [ ] **Step 2: Run and verify failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/tags_test.rb`

Expected: FAIL because `Admin::TagsController` is absent.

- [ ] **Step 3: Implement tag CRUD and compact forms**

Controller contract:

```ruby
class Admin::TagsController < Admin::BaseController
  before_action :set_tag, only: %i[edit update destroy]

  def index
    @tags = Tag.includes(:translations).order(created_at: :desc)
  end

  def new
    @tag = Tag.new
    prepare_translations(@tag)
  end

  def create
    @tag = Tag.new(protect_translation_locales(tag_params))
    if @tag.save
      redirect_to admin_tags_path, notice: "Tag created.", status: :see_other
    else
      prepare_translations(@tag)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@tag)
  end

  def update
    if @tag.update(protect_translation_locales(tag_params))
      redirect_to admin_tags_path, notice: "Tag saved.", status: :see_other
    else
      prepare_translations(@tag)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path, notice: "Tag deleted.", status: :see_other
  end

  private

  def set_tag = @tag = Tag.find(params[:id])

  def tag_params
    params.expect(tag: [
      { translations_attributes: [ %i[id locale name slug _destroy] ] }
    ])
  end
end
```

Render `admin/shared/locale_tabs` with the tag form, record, and tag translation-fields partial. Translation fields contain name and editable stable slug help text. Index cards list all available localized names/slugs. Delete confirmation reads “Delete this tag and remove it from all projects and posts?”.

- [ ] **Step 4: Run tests**

Run: `mise exec -- ruby bin/rails test test/requests/admin/tags_test.rb test/models/tag_translation_test.rb test/models/public_content_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/tags_controller.rb app/views/admin/tags test/requests/admin/tags_test.rb
git commit -m "feat(admin): manage localized tags"
```

---

### Task 7: Singleton Profile, Portrait, Social Links, and Accent

**Files:**

- Create: `app/controllers/admin/profiles_controller.rb`
- Create: `app/views/admin/profiles/edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/profiles_test.rb`
- Reuse: `public/icon.png` for the valid portrait upload.

**Interfaces:**

- Consumes: nullable `Profile.current`, nested translations, portrait MIME/extension/size validation, fixed accent enum, theme `<html data-accent>` contract.
- Produces: singleton profile editor and portrait purge route.

- [ ] **Step 1: Write failing request tests**

Test the editor against an empty database first: GET renders without persisting a row; the first PATCH creates the singleton plus its English translation; and a second PATCH includes that translation's persisted `id` and updates the same rows. Test `public_contact_email`, the three `social_links` keys, `accent`, portrait, and all three translations in one request. Assert blank social values are removed from the stored JSON. Test invalid email, invalid HTTP(S) social URL, invalid accent, and one `text/plain` portrait upload return 422 while preserving `headline` and `biography_markdown`; `test/models/public_content_test.rb` remains the MIME/extension/size matrix. Submit a persisted French translation with `locale: "vi"` and assert it remains French. Submit `profile: "not-an-object"` and assert 400. Test the portrait purge route only after the singleton exists. Test unauthenticated edit redirects.

Use this representative update:

```ruby
patch admin_profile_path, params: { profile: {
  public_contact_email: "hello@example.test", accent: "orange",
  social_links: { github: "https://github.com/owner", linkedin: "", website: "https://example.test" },
  portrait: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"),
  translations_attributes: {
    "0" => { locale: "en", display_name: "Portfolio Owner", headline: "Ideas. Interfaces. Impact.", introduction: "Short intro", biography_markdown: "# Biography", availability_label: "Available" },
    "1" => { locale: "fr", display_name: "Propriétaire", headline: "Des idées qui comptent", introduction: "Présentation", biography_markdown: "# Biographie", availability_label: "Disponible" },
    "2" => { locale: "vi", display_name: "", headline: "", introduction: "", biography_markdown: "", availability_label: "" }
  }
} }
```

- [ ] **Step 2: Run and verify failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/profiles_test.rb`

Expected: FAIL because `Admin::ProfilesController` is absent.

- [ ] **Step 3: Implement the singleton editor**

```ruby
class Admin::ProfilesController < Admin::BaseController
  before_action :set_profile, only: %i[edit update]
  before_action :find_profile, only: :portrait

  def edit
    prepare_translations(@profile)
  end

  def update
    attributes = protect_translation_locales(profile_params)
    attributes[:social_links] = attributes[:social_links].to_h.compact_blank if attributes[:social_links]
    if @profile.update(attributes)
      redirect_to edit_admin_profile_path, notice: "Profile saved.", status: :see_other
    else
      prepare_translations(@profile)
      render :edit, status: :unprocessable_entity
    end
  end

  def portrait
    @profile.portrait.purge
    redirect_to edit_admin_profile_path, notice: "Portrait removed.", status: :see_other
  end

  private

  def set_profile = @profile = Profile.current || Profile.new(singleton_guard: 1)
  def find_profile = @profile = Profile.current || raise(ActiveRecord::RecordNotFound)

  def profile_params
    params.expect(profile: [
      :public_contact_email, :accent, :portrait,
      {
        social_links: %i[github linkedin website],
        translations_attributes: [ %i[id locale display_name headline introduction biography_markdown availability_label _destroy] ]
      }
    ])
  end
end
```

Use `form_with model: @profile, url: admin_profile_path, method: :patch` so the same singleton route handles an unsaved first record and later updates. Form shared fields are contact email; labeled URL inputs for GitHub, LinkedIn, and website; portrait; and exactly five accent radios generated from `Profile::ACCENTS`. Show each radio's preset name and semantic accent swatch; no free-form color input. Translation fields are display name, headline, introduction, availability label, and `<%= render "admin/shared/markdown_editor", form: form, attribute: :biography_markdown, label: "Biography (Markdown)" %>`. Portrait removal uses `portrait_admin_profile_path`, DELETE, and an explicit Turbo confirmation.

- [ ] **Step 4: Run profile plus public accent regression tests**

Run: `mise exec -- ruby bin/rails test test/requests/admin/profiles_test.rb test/models/public_content_test.rb test/integration/public_content_test.rb`

Expected: PASS; the public layout still emits the selected `data-accent` value.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/profiles_controller.rb app/views/admin/profiles test/requests/admin/profiles_test.rb
git commit -m "feat(admin): manage profile and site accent"
```

---

### Task 8: Singleton Résumé and Locale-Specific PDFs

**Files:**

- Create: `app/controllers/admin/resumes_controller.rb`
- Create: `app/views/admin/resumes/edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/resumes_test.rb`
- Create: `test/fixtures/files/resume.pdf`

**Interfaces:**

- Consumes: nullable `Resume.current`, nested translations, `ResumeTranslation#pdf`, and Phase 2 PDF MIME/extension/size validation.
- Produces: résumé metadata/editor and ownership-scoped localized PDF purge.

- [ ] **Step 1: Write failing request tests**

Test the editor against an empty database first: GET renders without persisting a row; the first PATCH creates the singleton plus its English translation; and a second PATCH includes that translation's persisted `id` and updates the same rows. Test one update with `updated_on`, English and French text, and a distinct valid PDF on each translation. Assert English is required, optional blank Vietnamese is rejected rather than persisted, and one `text/plain` PDF upload returns 422 with text retained; `test/models/public_content_test.rb` remains the MIME/extension/size matrix. Submit a persisted French translation with `locale: "vi"` and assert it remains French. Submit `resume: "not-an-object"` and assert 400. Test removal only after the singleton exists, including that removing French PDF cannot remove English PDF or another translation's PDF. Test unauthenticated access.

The nested upload parameter is exact:

Create the small metadata-validation fixture as literal text; Phase 2 validates MIME type, extension, and byte size rather than parsing PDF internals:

```text
%PDF-1.4
%%EOF
```

Save those bytes as `test/fixtures/files/resume.pdf`, then submit:

```ruby
{
  translations_attributes: {
    "0" => { locale: "en", title: "Résumé", description: "English résumé", pdf: fixture_file_upload("files/resume.pdf", "application/pdf") },
    "1" => { locale: "fr", title: "CV", description: "CV français", pdf: fixture_file_upload("files/resume.pdf", "application/pdf") },
    "2" => { locale: "vi", title: "", description: "", pdf: nil }
  }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/resumes_test.rb`

Expected: FAIL because `Admin::ResumesController` is absent.

- [ ] **Step 3: Implement résumé update and secure PDF removal**

```ruby
class Admin::ResumesController < Admin::BaseController
  before_action :set_resume, only: %i[edit update]
  before_action :find_resume, only: :pdf

  def edit
    prepare_translations(@resume)
  end

  def update
    if @resume.update(protect_translation_locales(resume_params))
      redirect_to edit_admin_resume_path, notice: "Résumé saved.", status: :see_other
    else
      prepare_translations(@resume)
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    translation = @resume.translations.find(params[:translation_id])
    translation.pdf.purge
    redirect_to edit_admin_resume_path, notice: "PDF removed.", status: :see_other
  end

  private

  def set_resume = @resume = Resume.current || Resume.new(singleton_guard: 1)
  def find_resume = @resume = Resume.current || raise(ActiveRecord::RecordNotFound)

  def resume_params
    params.expect(resume: [
      :updated_on,
      { translations_attributes: [ %i[id locale title description pdf _destroy] ] }
    ])
  end
end
```

Use `form_with model: @resume, url: admin_resume_path, method: :patch` so the singleton route also creates the first row. The form uses a date input for `updated_on`; each locale panel contains title, description, and `file_field :pdf, accept: "application/pdf,.pdf"`. Show filename and byte size when attached. PDF removal uses `translation_pdf_admin_resume_path(translation_id: form.object.id)`, DELETE, and text “Remove the French PDF?” based on the tab locale. Do not build a media library.

- [ ] **Step 4: Run résumé and public download regressions**

Run: `mise exec -- ruby bin/rails test test/requests/admin/resumes_test.rb test/models/public_content_test.rb test/integration/public_content_test.rb`

Expected: PASS; admin upload changes are visible through the existing localized public download only where that translation exists.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/resumes_controller.rb app/views/admin/resumes test/requests/admin/resumes_test.rb test/fixtures/files/resume.pdf
git commit -m "feat(admin): manage localized resume files"
```

---

### Task 9: Mobile End-to-End CMS Workflow and Phase Acceptance

**Files:**

- Create: `test/requests/admin/cms_authorization_test.rb`
- Create: `test/system/admin_manages_content_test.rb`
- Modify only for discovered accessibility/layout defects: admin views and `app/assets/tailwind/application.css` created or modified in Tasks 1–8.

**Interfaces:**

- Consumes: all Phase 4 routes/forms, Phase 3 real two-factor system sign-in helper, Turbo/Stimulus.
- Produces: an authorization matrix for every Phase 4 controller and one regression proving the complete CMS workflow at phone and desktop widths.

- [ ] **Step 1: Write the failing phone-first system test**

```ruby
require "application_system_test_case"

class AdminManagesContentTest < ApplicationSystemTestCase
  setup do
    Profile.create!(
      public_contact_email: "owner@example.test",
      translations_attributes: {
        "0" => {
          locale: "en", display_name: "Portfolio Owner", headline: "Ideas. Interfaces. Impact.",
          introduction: "Short introduction", biography_markdown: "Biography", availability_label: "Available"
        }
      }
    )
    Resume.create!(
      updated_on: Date.new(2026, 9, 2),
      translations_attributes: {
        "0" => { locale: "en", title: "Résumé", description: "Current résumé" }
      }
    )
    sign_in_owner
    page.current_window.resize_to(320, 700)
  end

  test "owner creates translations, previews markdown, uploads assets, and changes accent" do
    visit new_admin_project_path
    fill_in "Role", with: "Lead developer"
    fill_in "Title", with: "Phone-first project", match: :first
    fill_in "Summary", with: "Created from a narrow viewport", match: :first
    fill_in "Body (Markdown)", with: "# Preview heading", match: :first
    attach_file "Cover image", Rails.root.join("public/icon.png")
    click_button "Preview", match: :first
    within("turbo-frame#project_en_markdown_preview") { assert_text "Preview heading" }
    fill_in "Body (Markdown)", with: "# Updated preview", match: :first
    click_button "Preview", match: :first
    within("turbo-frame#project_en_markdown_preview") { assert_text "Updated preview" }

    click_button "French"
    within("[role='tabpanel']:not([hidden])") do
      fill_in "Title", with: "Projet mobile"
      fill_in "Summary", with: "Résumé français"
      fill_in "Body (Markdown)", with: "# Aperçu"
    end
    click_button "Create project"
    assert_text "Project created."

    project = Project.order(:id).last
    assert_equal "phone-first-project", project.translations.find_by!(locale: "en").slug
    assert_equal %w[en fr], project.translations.order(:locale).pluck(:locale)
    assert project.cover_image.attached?

    visit edit_admin_profile_path
    choose "Orange"
    click_button "Save profile"
    assert_equal "orange", Profile.current.reload.accent

    visit edit_admin_resume_path
    fill_in "Updated on", with: "2026-09-02"
    attach_file "PDF", file_fixture("resume.pdf"), match: :first
    click_button "Save résumé"
    assert Resume.current.translations.find_by!(locale: "en").pdf.attached?

    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
      page.evaluate_script("document.documentElement.clientWidth")
  end

  test "locale tabs support keyboard navigation" do
    visit new_admin_post_path
    english = find("[role='tab']", text: "English")
    english.send_keys(:arrow_right)
    assert_equal "true", find("[role='tab']", text: "French")["aria-selected"]
    assert_selector "[role='tabpanel']:not([hidden])", text: /French/
    find("[role='tab']", text: "French").send_keys(:end)
    assert_equal "true", find("[role='tab']", text: "Vietnamese")["aria-selected"]
    find("[role='tab']", text: "Vietnamese").send_keys(:home)
    assert_equal "true", find("[role='tab']", text: "English")["aria-selected"]
  end

  test "preview request failures are visible without losing editor content" do
    visit new_admin_post_path
    fill_in "Body (Markdown)", with: "Unsaved body", match: :first
    editor = find("[data-controller~='markdown-preview']", match: :first)
    page.execute_script(
      'arguments[0].setAttribute("data-markdown-preview-url-value", "/missing-preview")',
      editor
    )

    click_button "Preview", match: :first

    within("turbo-frame#post_en_markdown_preview") do
      assert_text "Preview unavailable. Try again."
    end
    assert_field "Body (Markdown)", with: "Unsaved body", match: :first
  end
end
```

The request tests for Tasks 7 and 8 separately prove the first authenticated PATCH creates each missing singleton. Development seeds are not a production precondition. The system helper performs the actual Phase 3 password and TOTP flow; do not disable authentication in system tests.

Create the controller-level authorization matrix:

```ruby
require "test_helper"

class Admin::CmsAuthorizationTest < ActionDispatch::IntegrationTest
  test "anonymous sessions cannot reach any Phase 4 controller" do
    assert_cms_redirects_to(new_admin_session_path)
  end

  test "password-only sessions cannot reach any Phase 4 controller" do
    user = admin_users(:owner)
    post admin_session_path, params: {
      admin_login: { email: user.email, password: TEST_PASSWORD }
    }

    assert_cms_redirects_to(admin_totp_challenge_path)
  end

  test "server HTML exposes every locale when JavaScript is unavailable" do
    sign_in_as_admin
    get new_admin_project_path

    assert_response :success
    assert_select "[role='tabpanel']", count: 3
    assert_select "[role='tabpanel'][hidden]", count: 0
    assert_select "button[type='button'][role='tab']", count: 3
  end

  private

  def assert_cms_redirects_to(destination)
    [
      -> { get admin_projects_path },
      -> { get admin_posts_path },
      -> { get admin_tags_path },
      -> { get edit_admin_profile_path },
      -> { get edit_admin_resume_path },
      -> {
        post admin_markdown_preview_path,
          params: { preview: { markdown: "Text", frame_id: "post_en_markdown_preview" } }
      }
    ].each do |request|
      request.call
      assert_redirected_to destination
    end
  end
end
```

One inherited request per new controller is sufficient because every action inherits the unchanged `Admin::BaseController#require_admin!`; resource tests separately exercise each mutating action.

- [ ] **Step 2: Run and observe the first failure**

Run: `mise exec -- ruby bin/rails test test/requests/admin/cms_authorization_test.rb`

Expected: FAIL until all Phase 4 controllers and JavaScript-fallback tab markup exist.

Run: `mise exec -- ruby bin/rails test:system test/system/admin_manages_content_test.rb`

Expected: FAIL on the first missing label, inaccessible tab, preview replacement, or overflow defect; fix one observed defect at a time without adding a frontend framework.

- [ ] **Step 3: Correct only demonstrated accessibility and responsive defects**

Required final properties are:

```text
320 CSS px: no document-level horizontal overflow
200% zoom: actions remain present and reachable
All controls: visible labels and keyboard-visible focus
Tabs: role/aria-selected/aria-controls plus Left/Right/Home/End
Actions: minimum 44 CSS px touch height
Lists: cards at base width; denser grids only from md upward
Destructive links: explicit Turbo confirmation
Validation: 422 response bound to the submitted in-memory record
Preview: authenticated POST, sanitized server HTML, locale-specific Turbo Frame
```

Do not add screenshot gems, a component library, a rich-text editor, direct uploads, or autosave.

- [ ] **Step 4: Run the complete Phase 4 verification suite**

```bash
mise exec -- ruby bin/rails test test/models test/helpers/admin test/requests/admin
mise exec -- ruby bin/rails test:system test/system/admin_manages_content_test.rb
mise exec -- ruby bin/rails test
mise exec -- ruby bin/rails test:system
mise exec -- ruby bin/importmap audit
mise exec -- ruby bin/rubocop
mise exec -- ruby bin/brakeman --no-pager
```

Expected: every command exits 0. Brakeman must not report an authentication bypass, unsafe redirect, unrestricted mass assignment, or raw unsanitized preview. Manually repeat the create/edit/preview/upload/delete workflow at 320×568 and 1440×900, then zoom the browser to 200%; all content remains reachable and no page gains horizontal scrolling.

- [ ] **Step 5: Commit acceptance coverage**

```bash
git add test/requests/admin/cms_authorization_test.rb test/system/admin_manages_content_test.rb app/views/admin app/assets/tailwind/application.css
git commit -m "test(admin): cover mobile CMS workflow"
```

- [ ] **Step 6: Mark the phase boundary without editing the parent plan**

```bash
git status --short
git tag -a portfolio-v4-phase-4 -m "Portfolio v4 phase 4: admin CMS"
git show --stat --oneline portfolio-v4-phase-4
```

Expected: the worktree is clean before tagging; the tag points at the acceptance-tested commit. Do not edit or check a box in the immutable parent plan.

## Phase 4 Acceptance Checklist

- [ ] Every `/admin` CMS and preview endpoint redirects an unauthenticated or password-only session through Phase 3 authentication.
- [ ] Project, post, tag, profile, and résumé forms save shared fields and nested `en`, `fr`, `vi` records in one transaction.
- [ ] English remains required; untouched optional locale tabs do not create blank records.
- [ ] Persisted nested translations cannot be moved to another locale through submitted hidden-field changes.
- [ ] Project/post state badges are visible but state transitions remain deferred to Phase 5.
- [ ] Generated slugs stay unchanged after title/name edits unless the owner explicitly edits the slug; explicit values accept only lowercase ASCII kebab-case.
- [ ] Invalid nested data and invalid uploads return 422 with entered values and errors intact.
- [ ] New gallery uploads append without replacing existing images; cover, gallery, portrait, and locale-specific PDF deletion is ownership-scoped and confirmed.
- [ ] Successful form mutations redirect with 303; malformed structured parameter scopes return 400 rather than 500.
- [ ] Markdown preview requires full admin authentication, uses `MarkdownRenderer` plus the safe render boundary, returns `noindex, nofollow`, supports repeated previews, and replaces only the requested Turbo Frame.
- [ ] Accent accepts only `brown`, `green`, `lime`, `orange`, or `yellow` and updates the existing public semantic accent contract.
- [ ] Card/list layouts, forms, tabs, uploads, preview, and destructive actions work at 320 CSS pixels, desktop width, keyboard-only input, and 200% zoom.
- [ ] Full model, request, system, RuboCop, and Brakeman commands pass before the phase tag is created.
