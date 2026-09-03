# Phase 4: Admin CMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the authenticated owner a mobile-first CMS for every shared and localized content record, uploads, stable editable slugs, locale tabs, site accent selection, and sanitized Markdown previews.

**Architecture:** Keep the Rails monolith server-rendered. Resource controllers accept one shared record plus nested `translations_attributes`; a small admin helper and two Stimulus controllers provide accessible locale tabs and server-backed preview without introducing a component library or JSON API. Existing Phase 2 domain validations and Phase 3 authentication remain the authority for content safety and access control.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Hotwire/Turbo Frames, Stimulus, Tailwind CSS, SQLite, Active Storage, Commonmarker, Minitest, Capybara

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
- Use Rails defaults and the standard library before adding dependencies. The only planned application gems beyond generated Rails defaults are `commonmarker` and `rotp`.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.

---

## Scope Boundary and Consumed Interfaces

Phase 1 supplies Tailwind, Turbo, Stimulus, semantic theme/accent tokens, and the responsive layouts. Phase 2 supplies these exact domain interfaces: `MarkdownRenderer.call(markdown) -> String`, nullable `Profile.current`, nullable `Resume.current`, `Project#cover_image`, `Project#gallery_images`, `Post#cover_image`, `Profile#portrait`, `ResumeTranslation#pdf`, `Project#tags`, `Post#tags`, and translation associations named `translations`. It also supplies attachment MIME-type/filename-extension/size validations and localized slug uniqueness. Phase 3 supplies `Admin::BaseController#require_admin!`, `Current.admin_user`, the protected admin layout, `sign_in_as_admin`/`sign_out_admin` for request tests, and `sign_in_owner` for system tests.

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
- `app/views/admin/shared/_errors.html.erb`, `_locale_tabs.html.erb`, `_translation_controls.html.erb` — shared form UI.
- Resource views under `app/views/admin/projects/`, `posts/`, `tags/`, `profiles/`, and `resumes/` listed in their tasks.
- `test/helpers/admin/content_helper_test.rb`, `test/requests/admin/markdown_previews_test.rb`, resource request tests, and `test/system/admin_manages_content_test.rb`.
- Upload fixtures `test/fixtures/files/cover.png`, `portrait.png`, `resume.pdf`, `invalid.txt`.

**Modify**

- `config/routes.rb` — authenticated admin resource and preview routes.
- `app/controllers/admin/base_controller.rb` — build missing locale records before forms render.
- `app/controllers/admin/dashboard_controller.rb` and `app/views/admin/dashboard/show.html.erb` — actionable content counts and links.
- `app/views/layouts/admin.html.erb` — mobile navigation to all CMS sections.
- `app/models/project.rb`, `post.rb`, `tag.rb`, `profile.rb`, `resume.rb` — nested translation writes.
- `app/models/project_translation.rb`, `post_translation.rb`, `tag_translation.rb` — create-only slug generation.
- `app/assets/tailwind/application.css` only if Phase 3 lacks the two reusable admin classes specified in Task 1.
- Existing model files only to add nested-attribute declarations required by the forms; Phase 3 already provides request and system authentication helpers.

## Shared Parameter Contracts

All translation forms submit an indexed hash, not locale-named top-level keys:

```ruby
translations_attributes: {
  "0" => { id: "12", locale: "en", title: "Title", slug: "title", body_markdown: "Text", _destroy: "0" },
  "1" => { id: "13", locale: "fr", title: "Titre", slug: "titre", body_markdown: "Texte", _destroy: "0" },
  "2" => { locale: "vi", title: "", slug: "", body_markdown: "", _destroy: "0" }
}
```

Locale is permitted only to create a missing nested record. Association ownership plus `(parent_id, locale)` uniqueness prevents moving a translation between records or duplicating a locale. English `_destroy` is never rendered; optional translations expose it only after persistence. `state`, `scheduled_at`, `published_at`, rendered HTML fields, and Active Storage metadata are never permitted.

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
- Produces: named admin routes and `Admin::BaseController#prepare_translations(record)`.

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

Run: `bin/rails test test/requests/admin/dashboard_test.rb`

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

- [ ] **Step 4: Run the dashboard and authorization tests**

Run: `bin/rails test test/requests/admin/dashboard_test.rb test/requests/admin/authentication_test.rb`

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

  test "reports completion using the localized record's identifying field" do
    assert translation_complete?(ProjectTranslation.new(title: "Work"))
    assert translation_complete?(TagTranslation.new(name: "Rails"))
    assert translation_complete?(ProfileTranslation.new(display_name: "Owner"))
    refute translation_complete?(PostTranslation.new(title: ""))
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
  end
end
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `bin/rails test test/helpers/admin/content_helper_test.rb test/models/project_translation_test.rb test/models/post_translation_test.rb test/models/tag_translation_test.rb`

Expected: FAIL because the helper and create-only callbacks are absent.

- [ ] **Step 3: Add the minimal shared form interfaces**

Use this helper:

```ruby
module Admin::ContentHelper
  LOCALE_NAMES = { "en" => "English", "fr" => "French", "vi" => "Vietnamese" }.freeze

  def translation_complete?(translation)
    value = if translation.respond_to?(:title)
      translation.title
    elsif translation.respond_to?(:name)
      translation.name
    else
      translation.display_name
    end
    value.present?
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

Use the same declaration in `Post` with `title`, `slug`, `excerpt`, `body_markdown`; `Tag` with `name`, `slug`; `Profile` with `display_name`, `headline`, `introduction`, `biography_markdown`, `availability_label`; and `Resume` with `title`, `description`. Keep Phase 2's English-required validation authoritative.

In each slugged translation model add:

```ruby
before_validation :set_initial_slug, on: :create

private

def set_initial_slug
  self.slug = title.to_s.parameterize if slug.blank?
end
```

For `TagTranslation`, parameterize `name` instead of `title`.

`_errors.html.erb` renders `record.errors.full_messages` in an alert. `_translation_controls.html.erb` renders hidden `id` and `locale`, a completion badge, a read-only state badge when present, and an optional `_destroy` checkbox only when locale is not `en` and the translation is persisted.

`_locale_tabs.html.erb` receives `form:`, `record:`, and `fields_partial:`. Render three tab buttons and three corresponding panels in `en`, `fr`, `vi` order. Each button must have `role="tab"`, `aria-controls`, `aria-selected`, a 44px minimum height, and the completion/state badges. Each panel must have `role="tabpanel"`; only English starts visible. Within each panel use `form.fields_for :translations, translation` and render `fields_partial` with local `form:`.

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

Run: `bin/rails test test/helpers/admin/content_helper_test.rb test/models/project_translation_test.rb test/models/post_translation_test.rb test/models/tag_translation_test.rb && bin/importmap audit`

Expected: PASS; `bin/importmap audit` exits 0 because Phase 1 generated the app with Importmap.

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
- Create: `app/javascript/controllers/markdown_preview_controller.js`
- Create: `test/requests/admin/markdown_previews_test.rb`

**Interfaces:**

- Consumes: `MarkdownRenderer.call(markdown) -> String`, Phase 3 admin authentication, Turbo.
- Produces: `POST /admin/markdown_preview` accepting `preview[markdown]` and `preview[frame_id]`, returning one matching `<turbo-frame>`.

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
    assert_select "turbo-frame#post_en_markdown_preview" do
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
end
````

- [ ] **Step 2: Run and verify the controller is missing**

Run: `bin/rails test test/requests/admin/markdown_previews_test.rb`

Expected: FAIL with `uninitialized constant Admin::MarkdownPreviewsController`.

- [ ] **Step 3: Implement the authenticated server preview and thin Stimulus adapter**

```ruby
class Admin::MarkdownPreviewsController < Admin::BaseController
  FRAME_ID = /\A(?:project|post|profile)_(?:en|fr|vi)_markdown_preview\z/

  def create
    values = params.require(:preview).permit(:markdown, :frame_id)
    return head :unprocessable_entity unless values[:frame_id].match?(FRAME_ID)

    @frame_id = values[:frame_id]
    @html = MarkdownRenderer.call(values[:markdown].to_s)
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
```

```erb
<%= turbo_frame_tag @frame_id do %>
  <article class="prose max-w-none"><%= @html.html_safe %></article>
<% end %>
```

The `.html_safe` call is allowed only at this boundary because `MarkdownRenderer` is the Phase 2 sanitizer. The Stimulus controller sends CSRF-protected form data and replaces only the returned frame:

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
    if (response.ok) this.frameTarget.outerHTML = await response.text();
  }
}
```

Project, post, and profile Markdown field partials in later tasks wrap their textarea and frame in this controller, with a `type="button"` Preview button. There is no public or shareable preview token.

- [ ] **Step 4: Run the preview tests**

Run: `bin/rails test test/requests/admin/markdown_previews_test.rb test/services/markdown_renderer_test.rb`

Expected: PASS, including sanitization inherited from Phase 2.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/markdown_previews_controller.rb app/views/admin/markdown_previews/create.html.erb app/javascript/controllers/markdown_preview_controller.js test/requests/admin/markdown_previews_test.rb
git commit -m "feat(admin): add authenticated Markdown previews"
```

---

### Task 4: Project CRUD, Tags, and Shared Image Management

**Files:**

- Create: `app/controllers/admin/projects_controller.rb`
- Create: `app/views/admin/projects/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_translation_fields.html.erb`
- Create: `test/requests/admin/projects_test.rb`
- Create: `test/fixtures/files/cover.png`, `invalid.txt`

**Interfaces:**

- Consumes: nested translations, `Project#tags`, `cover_image`, `gallery_images`, attachment validations, locale tabs, Markdown preview.
- Produces: full project CRUD and explicit cover/gallery purge routes.

- [ ] **Step 1: Write failing request tests for create, update, validation preservation, and removal**

The test file uses `fixture_file_upload("files/cover.png", "image/png")` and covers these exact requests:

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
    assert_difference ["Project.count", "ProjectTranslation.count"], 1 do
      post admin_projects_path, params: { project: {
        role: "Lead developer", started_on: "2026-01-01", ended_on: "2026-06-01",
        live_url: "https://example.test", source_url: "https://github.com/example/work",
        featured_position: "1", tag_ids: [@tag.id],
        cover_image: fixture_file_upload("files/cover.png", "image/png"),
        translations_attributes: {
          "0" => { locale: "en", title: "Useful Work", slug: "", summary: "English summary", body_markdown: "# English" },
          "1" => { locale: "fr", title: "Travail utile", slug: "travail-utile", summary: "Résumé", body_markdown: "# Français" },
          "2" => { locale: "vi", title: "", slug: "", summary: "", body_markdown: "" }
        }
      } }
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

  test "renders entered translations and upload errors with 422" do
    post admin_projects_path, params: { project: {
      role: "Lead", cover_image: fixture_file_upload("files/invalid.txt", "text/plain"),
      translations_attributes: { "0" => { locale: "en", title: "Entered title", summary: "Entered summary", body_markdown: "Entered body" } }
    } }
    assert_response :unprocessable_entity
    assert_select "input[value='Entered title']"
    assert_select "[role='alert']", text: /cover image/i
  end

  test "purges only an owned gallery attachment" do
    project = create_project
    project.gallery_images.attach(io: file_fixture("cover.png").open, filename: "one.png", content_type: "image/png")
    attachment = project.gallery_images.first
    delete gallery_image_admin_project_path(project, attachment_id: attachment.id)
    assert_redirected_to edit_admin_project_path(project)
    refute ActiveStorage::Attachment.exists?(attachment.id)
  end

  test "destroys a project after confirmation is submitted" do
    project = create_project
    assert_difference("Project.count", -1) { delete admin_project_path(project) }
    assert_redirected_to admin_projects_path
  end

  private

  def create_project
    Project.create!(role: "Engineer", translations_attributes: {
      "0" => { locale: "en", title: "Existing Project", slug: "existing-project", summary: "Summary", body_markdown: "Body" }
    })
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run: `bin/rails test test/requests/admin/projects_test.rb`

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
    @project = Project.new(project_params)
    if @project.save
      redirect_to edit_admin_project_path(@project), notice: "Project created."
    else
      prepare_translations(@project)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@project)
  end

  def update
    if @project.update(project_params)
      redirect_to edit_admin_project_path(@project), notice: "Project saved."
    else
      prepare_translations(@project)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to admin_projects_path, notice: "Project deleted."
  end

  def cover_image
    @project.cover_image.purge
    redirect_to edit_admin_project_path(@project), notice: "Cover image removed."
  end

  def gallery_image
    @project.gallery_images.attachments.find(params[:attachment_id]).purge
    redirect_to edit_admin_project_path(@project), notice: "Gallery image removed."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :role, :started_on, :ended_on, :live_url, :source_url, :featured_position, :cover_image,
      gallery_images: [], tag_ids: [],
      translations_attributes: %i[id locale title slug summary body_markdown _destroy]
    )
  end
end
```

The scoped `attachments.find` is required: it prevents deleting another record's blob by ID.

- [ ] **Step 4: Build all project views**

`index.html.erb` uses record cards, not a narrow table. Each card shows available locale/state badges and Edit/Delete actions. Delete uses `data: { turbo_method: :delete, turbo_confirm: "Delete this project and all translations?" }`.

`new.html.erb` and `edit.html.erb` render `_form`. `_form.html.erb` uses `form_with model: [:admin, project]`, renders shared errors, shared metadata fields, `collection_check_boxes :tag_ids, Tag.includes(:translations).order(:id), :id, ->(tag) { tag.translations.find { |item| item.locale == "en" }&.name || "Tag ##{tag.id}" }`, `file_field :cover_image, accept: "image/png,image/jpeg,image/webp"`, and `file_field :gallery_images, multiple: true` with the same accept list. Existing attachment removal links use the named DELETE routes and explicit confirmations.

`_translation_fields.html.erb` renders hidden controls, title, editable slug with help text “Generated from the title when first saved; later title changes do not change it,” summary, and body Markdown. Wrap the textarea/button/frame with:

```erb
<% frame_id = markdown_preview_frame_id(form.object) %>
<div data-controller="markdown-preview"
     data-markdown-preview-url-value="<%= admin_markdown_preview_path %>"
     data-markdown-preview-frame-id-value="<%= frame_id %>">
  <%= form.label :body_markdown, "Body (Markdown)" %>
  <%= form.text_area :body_markdown, rows: 18, data: { markdown_preview_target: "source" } %>
  <button type="button" class="admin-action" data-action="markdown-preview#render">Preview</button>
  <%= turbo_frame_tag frame_id, data: { markdown_preview_target: "frame" } do %>
    <p>Preview appears here.</p>
  <% end %>
</div>
```

Every input has a visible label; actions have `min-h-11`; form groups stack at the base breakpoint and use two columns only at `md:`. Render entered values from the bound invalid object, never from a reload.

- [ ] **Step 5: Run project tests and manually inspect phone layout**

Run: `bin/rails test test/requests/admin/projects_test.rb test/models/project_test.rb test/models/project_translation_test.rb`

Run: `bin/rails server`, sign in, open `/admin/projects/new` at 320×568, and verify no horizontal scroll, each locale tab/action is touch reachable, invalid values survive, preview updates only its locale, and image removal asks for confirmation.

Expected: all automated tests PASS and the manual checks succeed.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/projects_controller.rb app/views/admin/projects test/requests/admin/projects_test.rb test/fixtures/files/cover.png test/fixtures/files/invalid.txt
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

Create tests parallel in assertion depth—not copied controller internals—to prove: unauthenticated access redirects; create persists English and Vietnamese while rejecting a blank French tab; selected tags and an image persist; invalid MIME type returns 422 with title/body still in the response; title-only update leaves the old slug; explicitly edited slug persists; `DELETE /admin/posts/:id/cover_image` purges the post's cover; destroy removes the post and redirects.

Use this create payload in the test:

```ruby
post admin_posts_path, params: { post: {
  tag_ids: [@tag.id], cover_image: fixture_file_upload("files/cover.png", "image/png"),
  translations_attributes: {
    "0" => { locale: "en", title: "A careful post", slug: "", excerpt: "English excerpt", body_markdown: "# English" },
    "1" => { locale: "fr", title: "", slug: "", excerpt: "", body_markdown: "" },
    "2" => { locale: "vi", title: "Bài viết", slug: "bai-viet", excerpt: "Tóm tắt", body_markdown: "# Tiếng Việt" }
  }
} }
```

Assert `PostTranslation.count` changes by 2, its states are both `draft`, and the generated English slug is `a-careful-post`.

- [ ] **Step 2: Run and verify failure**

Run: `bin/rails test test/requests/admin/posts_test.rb`

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement post CRUD**

Use the same status and redirect policy as projects. Exact permitted parameters are:

```ruby
params.require(:post).permit(
  :cover_image, tag_ids: [],
  translations_attributes: %i[id locale title slug excerpt body_markdown _destroy]
)
```

`index` loads `Post.includes(:translations, :tags).order(created_at: :desc)`. `new`, failed `create`, `edit`, and failed `update` call `prepare_translations`. `cover_image` calls `@post.cover_image.purge`; `destroy` calls `@post.destroy!`. All actions inherit `Admin::BaseController`; do not repeat authentication checks.

Build card-based index/new/edit/form views. The translation fields are title, slug, excerpt, and Markdown body; include the same exact preview wrapper from Task 4 with the post-specific frame ID generated by the helper. The cover input accepts PNG, JPEG, and WebP. Tag labels use their English translation. Delete and cover removal require Turbo confirmations.

- [ ] **Step 4: Run focused tests**

Run: `bin/rails test test/requests/admin/posts_test.rb test/models/post_test.rb test/models/post_translation_test.rb test/requests/admin/markdown_previews_test.rb`

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

Test that create with English/French and blank Vietnamese produces exactly two translations; blank English returns 422 with the French value preserved; duplicate French slug returns 422; renaming a tag does not rewrite its slug; an explicit slug update works; destroy removes the tag and its taggings but not associated projects/posts; unauthenticated index redirects.

Use this exact valid payload:

```ruby
{ tag: { translations_attributes: {
  "0" => { locale: "en", name: "Web performance", slug: "" },
  "1" => { locale: "fr", name: "Performance web", slug: "performance-web" },
  "2" => { locale: "vi", name: "", slug: "" }
} } }
```

- [ ] **Step 2: Run and verify failure**

Run: `bin/rails test test/requests/admin/tags_test.rb`

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
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to admin_tags_path, notice: "Tag created."
    else
      prepare_translations(@tag)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@tag)
  end

  def update
    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: "Tag saved."
    else
      prepare_translations(@tag)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path, notice: "Tag deleted."
  end

  private

  def set_tag = @tag = Tag.find(params[:id])

  def tag_params
    params.require(:tag).permit(translations_attributes: %i[id locale name slug _destroy])
  end
end
```

Use locale tabs even though fields are short, preserving the same mobile interaction. Translation fields contain name and editable stable slug help text. Index cards list all available localized names/slugs. Delete confirmation reads “Delete this tag and remove it from all projects and posts?”.

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/requests/admin/tags_test.rb test/models/tag_test.rb test/models/tag_translation_test.rb`

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
- Create: `test/fixtures/files/portrait.png`

**Interfaces:**

- Consumes: nullable `Profile.current`, nested translations, portrait MIME/extension/size validation, fixed accent enum, theme `<html data-accent>` contract.
- Produces: singleton profile editor and portrait purge route.

- [ ] **Step 1: Write failing request tests**

Test the editor against an empty database first: GET renders, the first PATCH creates the singleton plus its English translation, and a second PATCH updates the same row. Test `public_contact_email`, the three `social_links` keys, `accent`, portrait, and all three translations in one request. Assert blank social values are removed from the stored JSON. Test invalid email, invalid HTTP(S) social URL, invalid accent, and invalid portrait MIME/extension/size return 422 while preserving `headline` and `biography_markdown`. Test the portrait purge route only after the singleton exists. Test unauthenticated edit redirects.

Use this representative update:

```ruby
patch admin_profile_path, params: { profile: {
  public_contact_email: "hello@example.test", accent: "orange",
  social_links: { github: "https://github.com/owner", linkedin: "", website: "https://example.test" },
  portrait: fixture_file_upload("files/portrait.png", "image/png"),
  translations_attributes: {
    "0" => { id: english.id, locale: "en", display_name: "Portfolio Owner", headline: "Ideas. Interfaces. Impact.", introduction: "Short intro", biography_markdown: "# Biography", availability_label: "Available" },
    "1" => { locale: "fr", display_name: "Propriétaire", headline: "Des idées qui comptent", introduction: "Présentation", biography_markdown: "# Biographie", availability_label: "Disponible" },
    "2" => { locale: "vi", display_name: "", headline: "", introduction: "", biography_markdown: "", availability_label: "" }
  }
} }
```

- [ ] **Step 2: Run and verify failure**

Run: `bin/rails test test/requests/admin/profiles_test.rb`

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
    attributes = profile_params
    attributes[:social_links] = attributes[:social_links].to_h.compact_blank
    if @profile.update(attributes)
      redirect_to edit_admin_profile_path, notice: "Profile saved."
    else
      prepare_translations(@profile)
      render :edit, status: :unprocessable_entity
    end
  end

  def portrait
    @profile.portrait.purge
    redirect_to edit_admin_profile_path, notice: "Portrait removed."
  end

  private

  def set_profile = @profile = Profile.current || Profile.new(singleton_guard: 1)
  def find_profile = @profile = Profile.current || raise(ActiveRecord::RecordNotFound)

  def profile_params
    params.require(:profile).permit(
      :public_contact_email, :accent, :portrait,
      social_links: %i[github linkedin website],
      translations_attributes: %i[id locale display_name headline introduction biography_markdown availability_label _destroy]
    )
  end
end
```

Use `form_with model: @profile, url: admin_profile_path, method: :patch` so the same singleton route handles an unsaved first record and later updates. Form shared fields are contact email; labeled URL inputs for GitHub, LinkedIn, and website; portrait; and exactly five accent radios generated from `Profile::ACCENTS`. Show each radio's preset name and semantic accent swatch; no free-form color input. Translation fields are display name, headline, introduction, availability label, and biography Markdown with the Task 4 preview wrapper. Portrait removal requires confirmation.

- [ ] **Step 4: Run profile plus public accent regression tests**

Run: `bin/rails test test/requests/admin/profiles_test.rb test/models/profile_test.rb test/requests/public/home_test.rb`

Expected: PASS; the public layout still emits the selected `data-accent` value.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/profiles_controller.rb app/views/admin/profiles test/requests/admin/profiles_test.rb test/fixtures/files/portrait.png
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

Test the editor against an empty database first: GET renders, the first PATCH creates the singleton plus its English translation, and a second PATCH updates the same row. Test one update with `updated_on`, English and French text, and a distinct valid PDF on each translation. Assert English is required, optional blank Vietnamese is rejected rather than persisted, and invalid PDF MIME, extension, or size returns 422 with text retained. Test removal only after the singleton exists, including that removing French PDF cannot remove English PDF or another translation's PDF. Test unauthenticated access.

The nested upload parameter is exact:

```ruby
translations_attributes: {
  "0" => { id: english.id, locale: "en", title: "Résumé", description: "English résumé", pdf: fixture_file_upload("files/resume.pdf", "application/pdf") },
  "1" => { locale: "fr", title: "CV", description: "CV français", pdf: fixture_file_upload("files/resume.pdf", "application/pdf") },
  "2" => { locale: "vi", title: "", description: "", pdf: nil }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `bin/rails test test/requests/admin/resumes_test.rb`

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
    if @resume.update(resume_params)
      redirect_to edit_admin_resume_path, notice: "Résumé saved."
    else
      prepare_translations(@resume)
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    translation = @resume.translations.find(params[:translation_id])
    translation.pdf.purge
    redirect_to edit_admin_resume_path, notice: "PDF removed."
  end

  private

  def set_resume = @resume = Resume.current || Resume.new(singleton_guard: 1)
  def find_resume = @resume = Resume.current || raise(ActiveRecord::RecordNotFound)

  def resume_params
    params.require(:resume).permit(
      :updated_on,
      translations_attributes: %i[id locale title description pdf _destroy]
    )
  end
end
```

Use `form_with model: @resume, url: admin_resume_path, method: :patch` so the singleton route also creates the first row. The form uses a date input for `updated_on`; each locale panel contains title, description, and `file_field :pdf, accept: "application/pdf,.pdf"`. Show filename and byte size when attached. PDF removal uses `translation_pdf_admin_resume_path(translation_id: form.object.id)`, DELETE, and text “Remove the French PDF?” based on the tab locale. Do not build a media library.

- [ ] **Step 4: Run résumé and public download regressions**

Run: `bin/rails test test/requests/admin/resumes_test.rb test/models/resume_test.rb test/models/resume_translation_test.rb test/requests/public/resume_test.rb`

Expected: PASS; admin upload changes are visible through the existing localized public download only where that translation exists.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/resumes_controller.rb app/views/admin/resumes test/requests/admin/resumes_test.rb test/fixtures/files/resume.pdf
git commit -m "feat(admin): manage localized resume files"
```

---

### Task 9: Mobile End-to-End CMS Workflow and Phase Acceptance

**Files:**

- Create: `test/system/admin_manages_content_test.rb`
- Modify only for discovered accessibility/layout defects: admin views and `app/assets/tailwind/application.css` created or modified in Tasks 1–8.

**Interfaces:**

- Consumes: all Phase 4 routes/forms, Phase 3 real two-factor system sign-in helper, Turbo/Stimulus.
- Produces: one regression proving the complete CMS workflow at phone and desktop widths.

- [ ] **Step 1: Write the failing phone-first system test**

```ruby
require "application_system_test_case"

class AdminManagesContentTest < ApplicationSystemTestCase
  setup do
    sign_in_owner
    page.current_window.resize_to(320, 700)
  end

  test "owner creates translations, previews markdown, uploads assets, and changes accent" do
    visit new_admin_project_path
    fill_in "Role", with: "Lead developer"
    fill_in "Title", with: "Phone-first project", match: :first
    fill_in "Summary", with: "Created from a narrow viewport", match: :first
    fill_in "Body (Markdown)", with: "# Preview heading", match: :first
    attach_file "Cover image", file_fixture("cover.png")
    click_button "Preview", match: :first
    within("turbo-frame#project_en_markdown_preview") { assert_text "Preview heading" }

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
  end
end
```

Create `Profile.current`, `Resume.current`, and their English translations in the system-test setup; development seeds are not a production precondition. The request tests for Tasks 7 and 8 must separately prove the first authenticated PATCH creates each missing singleton. The system helper performs the actual Phase 3 password and TOTP flow; do not disable authentication in system tests.

- [ ] **Step 2: Run and observe the first failure**

Run: `bin/rails test:system test/system/admin_manages_content_test.rb`

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
bin/rails test test/models test/helpers/admin test/requests/admin
bin/rails test:system test/system/admin_manages_content_test.rb
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
```

Expected: every command exits 0. Brakeman must not report an authentication bypass, unsafe redirect, unrestricted mass assignment, or raw unsanitized preview. Manually repeat the create/edit/preview/upload/delete workflow at 320×568 and 1440×900, then zoom the browser to 200%; all content remains reachable and no page gains horizontal scrolling.

- [ ] **Step 5: Commit acceptance coverage**

```bash
git add test/system/admin_manages_content_test.rb app/views/admin app/assets/tailwind/application.css
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
- [ ] Project/post state badges are visible but state transitions remain deferred to Phase 5.
- [ ] Generated slugs stay unchanged after title/name edits unless the owner explicitly edits the slug.
- [ ] Invalid nested data and invalid uploads return 422 with entered values and errors intact.
- [ ] Cover, gallery, portrait, and locale-specific PDF deletion is ownership-scoped and confirmed.
- [ ] Markdown preview requires full admin authentication, uses `MarkdownRenderer`, returns `noindex, nofollow`, and replaces only the requested Turbo Frame.
- [ ] Accent accepts only `brown`, `green`, `lime`, `orange`, or `yellow` and updates the existing public semantic accent contract.
- [ ] Card/list layouts, forms, tabs, uploads, preview, and destructive actions work at 320 CSS pixels, desktop width, keyboard-only input, and 200% zoom.
- [ ] Full model, request, system, RuboCop, and Brakeman commands pass before the phase tag is created.
