# Portfolio v4 Publishing and Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner publish, unpublish, and schedule each project or post translation independently while enforcing English-first publication and catching up overdue work safely.

**Architecture:** A shared `PublishableTranslation` concern owns the transitions and query scopes shared by both translation models. Singular nested `publication` resources give each translation conventional create, update, and destroy endpoints; standalone forms render after the existing editor form, and a small Stimulus adapter converts browser-local schedule input to an exact ISO 8601 instant. One recurring Solid Queue job scans every due English record before optional locales so retries and downtime catch-up remain idempotent; the dashboard reads the same scopes.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Active Record, Active Job, Solid Queue, SQLite, Hotwire/Turbo, Tailwind CSS, Minitest, Capybara

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

**Parent plan:** `docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md` — its Phase 5 interface is revised by this plan.

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

## Preconditions and Fixed Assumptions

Phase 1 through Phase 4 are accepted before this plan starts. This plan consumes these exact earlier-phase contracts:

- `Project#translations` and `Post#translations` are `has_many` associations using `ProjectTranslation` and `PostTranslation`.
- Both translation tables already have string `locale` and `state` columns plus nullable `scheduled_at` and `published_at` datetime columns. Their string enum values are `draft`, `scheduled`, and `published`.
- Project translation authored fields are `title`, `slug`, `summary`, and `body_markdown`; post translation authored fields are `title`, `slug`, `excerpt`, and `body_markdown`.
- `ProjectTranslation.publicly_visible(locale:)` and `PostTranslation.publicly_visible(locale:)` select only `published` rows in the requested locale.
- `Admin::BaseController` authenticates the owner before every inherited action.
- `sign_in_as_admin` is the Phase 3 request-test helper. System tests use `sign_in_owner`, which signs in the existing singleton owner fixture through fields `Email`, `Password`, and `Six-digit code`.
- Phase 4 provides `edit_admin_project_path`, `edit_admin_post_path`, project/post translation tab partials, and the protected `Admin::DashboardController#show` at `admin_root_path`.

If an earlier phase has not produced one of these contracts, stop and finish that phase rather than adding compatibility code here.

## File Map

| Path                                                                 | Responsibility                                                                           |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `app/models/concerns/publishable_translation.rb`                     | Shared transition methods, English-first guard, and due/upcoming scopes                  |
| `app/models/project_translation.rb`                                  | Includes the concern and returns its `Project` publication parent                        |
| `app/models/post_translation.rb`                                     | Includes the concern and returns its `Post` publication parent                           |
| `config/routes.rb`                                                   | Singular nested publication resources for both translation types                         |
| `app/controllers/admin/project_translations/publications_controller.rb` | Project translation publication create, update, and destroy actions                    |
| `app/controllers/admin/post_translations/publications_controller.rb` | Post translation publication create, update, and destroy actions                          |
| `app/views/admin/shared/_publication_controls.html.erb`              | Standalone per-locale forms rendered outside the content editor form                      |
| `app/views/admin/projects/edit.html.erb`                              | Renders controls for persisted project translations after the editor                     |
| `app/views/admin/posts/edit.html.erb`                                 | Renders controls for persisted post translations after the editor                        |
| `app/javascript/controllers/schedule_time_controller.js`             | Converts browser-local input to an ISO instant and rejects DST gaps                      |
| `app/javascript/controllers/local_time_controller.js`                | Converts UTC fallback text to browser-local schedule text                                 |
| `app/jobs/publish_due_translations_job.rb`                           | Idempotent English-first scan over both translation models                               |
| `config/recurring.yml`                                               | Runs the due scan every minute in production                                             |
| `app/controllers/admin/dashboard_controller.rb`                      | Queries draft, upcoming, and blocked-overdue translations                                |
| `app/views/admin/dashboard/show.html.erb`                            | Extends the existing dashboard with actionable publishing summaries                      |
| `test/models/publishable_translation_test.rb`                        | Shared state-transition, validation, and idempotency coverage                            |
| `test/requests/admin/project_translations/publications_test.rb`       | Project publication authentication, parsing, redirects, and form structure               |
| `test/requests/admin/post_translations/publications_test.rb`          | Post publication authentication, parsing, redirects, and form structure                  |
| `test/jobs/publish_due_translations_job_test.rb`                     | Due scan, catch-up, ordering, retry, and idempotency coverage                            |
| `test/config/recurring_schedule_test.rb`                             | Locks the recurring production schedule to the intended job                              |
| `test/requests/admin/dashboard_test.rb`                               | Existing dashboard coverage extended with publishing summaries                           |
| `test/integration/public_content_test.rb`                             | Public 404/200 isolation across publication transitions                                  |
| `test/system/admin_publishing_test.rb`                               | Owner workflow and public visibility acceptance coverage                                 |

## Interfaces Delivered

```ruby
module PublishableTranslation
  class EnglishMustBePublished < StandardError; end
  class InvalidScheduleTime < StandardError; end

  # ActiveRecord scopes
  due(at = Time.current)
  upcoming(at = Time.current)

  # Returns self; repeated publication of an already-published row performs no write.
  def publish = self

  # Returns self; at must be later than Time.current.
  def schedule(at:) = self

  # Returns self and preserves slug.
  def unpublish = self

  # Returns Project or Post.
  def publication_parent

  # Returns true for English, or when the parent's English translation is published.
  def publishable?
end

class PublishDueTranslationsJob < ApplicationJob
  def perform
  end
end
```

No service object, event table, state-machine gem, or separate scheduler is added. The three states and two timestamps already model the required workflow.

---

### Task 1: Centralize Publication State Transitions

**Files:**

- Create: `app/models/concerns/publishable_translation.rb`
- Modify: `app/models/project_translation.rb`
- Modify: `app/models/post_translation.rb`
- Test: `test/models/publishable_translation_test.rb`

**Interfaces:**

- Consumes: Existing string enums and translation-parent associations listed in Preconditions.
- Produces: `due`, `upcoming`, `publish`, `schedule`, `unpublish`, `publication_parent`, and `publishable?` exactly as documented above.

- [ ] **Step 1: Write the failing model tests**

Create `test/models/publishable_translation_test.rb`:

```ruby
require "test_helper"

class PublishableTranslationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "publishing English records the current time and clears its schedule" do
    translation = create_project.translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: 1.hour.ago)
    publication_time = Time.zone.local(2026, 9, 2, 12, 0, 0)

    travel_to publication_time do
      assert_same translation, translation.publish
    end

    translation.reload
    assert_predicate translation, :published?
    assert_equal publication_time, translation.published_at
    assert_nil translation.scheduled_at
  end

  test "non-English publication requires a published English sibling" do
    project = create_project(optional_locales: ["fr"])
    french = project.translations.find_by!(locale: "fr")

    error = assert_raises(PublishableTranslation::EnglishMustBePublished) do
      french.publish
    end

    assert_equal "Publish the English translation first", error.message
    assert_predicate french.reload, :draft?
    assert_nil french.published_at
  end

  test "non-English publication succeeds after English publication" do
    project = create_project(optional_locales: ["fr"])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")

    travel_to 2.minutes.ago do
      english.publish
    end
    travel_to 1.minute.ago do
      french.publish
    end

    assert_predicate french.reload, :published?
  end

  test "normal validation cannot bypass English-first publication" do
    project = create_project(optional_locales: ["fr"])
    french = project.translations.find_by!(locale: "fr")
    french.assign_attributes(state: :published, published_at: Time.current)

    assert_not french.valid?
    assert_includes french.errors[:state], "requires the English translation to be published first"
  end

  test "unpublishing English does not cascade to an independently published locale" do
    project = create_project(optional_locales: ["fr"])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    english.publish
    french.publish

    english.unpublish

    assert_predicate english.reload, :draft?
    assert_predicate french.reload, :published?
  end

  test "scheduling uses a future time and clears an old publication time" do
    translation = create_post.translations.find_by!(locale: "en")
    travel_to 1.day.ago do
      translation.publish
    end
    scheduled_time = 2.hours.from_now

    assert_same translation, translation.schedule(at: scheduled_time)

    translation.reload
    assert_predicate translation, :scheduled?
    assert_equal scheduled_time, translation.scheduled_at
    assert_nil translation.published_at
  end

  test "scheduling rejects blank or non-future times without changing the row" do
    translation = create_post.translations.find_by!(locale: "en")

    [nil, 1.minute.ago].each do |invalid_time|
      assert_raises(PublishableTranslation::InvalidScheduleTime) do
        translation.schedule(at: invalid_time)
      end
    end

    assert_predicate translation.reload, :draft?
    assert_nil translation.scheduled_at
  end

  test "unpublishing returns to draft and preserves the localized slug" do
    translation = create_project.translations.find_by!(locale: "en")
    original_slug = translation.slug
    travel_to 1.minute.ago do
      translation.publish
    end

    assert_same translation, translation.unpublish

    translation.reload
    assert_predicate translation, :draft?
    assert_equal original_slug, translation.slug
    assert_nil translation.scheduled_at
    assert_nil translation.published_at
  end

  test "publishing an already-published translation performs no second write" do
    translation = create_project.translations.find_by!(locale: "en")
    first_time = Time.zone.local(2026, 9, 2, 12, 0, 0)
    travel_to first_time do
      translation.publish
    end
    first_updated_at = translation.reload.updated_at

    travel 1.hour do
      assert_no_changes -> { translation.reload.attributes.slice("published_at", "updated_at") } do
        translation.publish
      end
    end

    assert_equal first_time, translation.published_at
    assert_equal first_updated_at, translation.updated_at
  end

  test "due and upcoming scopes partition scheduled rows at the cutoff" do
    post = create_post(optional_locales: ["fr"])
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    due = post.translations.find_by!(locale: "en")
    upcoming = post.translations.find_by!(locale: "fr")
    due.update_columns(state: "scheduled", scheduled_at: now)
    upcoming.update_columns(state: "scheduled", scheduled_at: now + 1.minute)

    assert_equal [due], PostTranslation.due(now).to_a
    assert_equal [upcoming], PostTranslation.upcoming(now).to_a
  end

  test "project and post translations expose their publication parent" do
    project = create_project
    post = create_post

    assert_equal project, project.translations.first.publication_parent
    assert_equal post, post.translations.first.publication_parent
  end

  private

  def create_project(optional_locales: [])
    Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: translation_attributes("Project", optional_locales, summary: "Summary")
    )
  end

  def create_post(optional_locales: [])
    Post.create!(
      translations_attributes: translation_attributes("Post", optional_locales, excerpt: "Excerpt")
    )
  end

  def translation_attributes(prefix, optional_locales, summary: nil, excerpt: nil)
    (["en"] + optional_locales).map do |locale|
      {
        locale: locale,
        title: "#{prefix} #{locale}",
        slug: "#{prefix.downcase}-#{locale}",
        summary: summary,
        excerpt: excerpt,
        body_markdown: "# #{prefix} #{locale}"
      }.compact
    end
  end
end
```

- [ ] **Step 2: Run the model test and verify the concern is missing**

Run:

```bash
mise exec -- ruby bin/rails test test/models/publishable_translation_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublishableTranslation` or `NoMethodError` for `publish`.

- [ ] **Step 3: Add the minimal shared concern**

Create `app/models/concerns/publishable_translation.rb`:

```ruby
module PublishableTranslation
  extend ActiveSupport::Concern

  class EnglishMustBePublished < StandardError; end
  class InvalidScheduleTime < StandardError; end

  included do
    scope :due, ->(at = Time.current) { scheduled.where(scheduled_at: ..at) }
    scope :upcoming, ->(at = Time.current) { scheduled.where("scheduled_at > ?", at) }

    validate :english_is_published_before_optional_locale, if: :publishing_optional_locale?
  end

  def publish
    with_lock do
      return self if published?
      raise EnglishMustBePublished, "Publish the English translation first" unless publishable?

      update!(state: :published, scheduled_at: nil, published_at: Time.current)
    end

    self
  end

  def schedule(at:)
    raise InvalidScheduleTime, "Choose a future publication time" unless at && at > Time.current

    with_lock do
      update!(state: :scheduled, scheduled_at: at, published_at: nil)
    end

    self
  end

  def unpublish
    with_lock do
      return self if draft?

      update!(state: :draft, scheduled_at: nil, published_at: nil)
    end

    self
  end

  def publishable?
    locale == "en" || publication_parent.translations.published.exists?(locale: "en")
  end

  private

  def publishing_optional_locale?
    locale != "en" && published? && will_save_change_to_state?
  end

  def english_is_published_before_optional_locale
    errors.add(:state, "requires the English translation to be published first") unless publishable?
  end
end
```

In `app/models/project_translation.rb`, include the concern directly below the class declaration and add the parent method:

```ruby
class ProjectTranslation < ApplicationRecord
  include PublishableTranslation

  belongs_to :project, inverse_of: :translations

  def publication_parent
    project
  end
end
```

Preserve every Phase 2 validation, enum, callback, and scope already in the class. In particular, keep the existing `scheduled_at` and `published_at` validations in each model; do not duplicate them or the enum in the concern.

In `app/models/post_translation.rb`, make the equivalent focused change:

```ruby
class PostTranslation < ApplicationRecord
  include PublishableTranslation

  belongs_to :post, inverse_of: :translations

  def publication_parent
    post
  end
end
```

Preserve every existing post translation rule around this addition.

- [ ] **Step 4: Run focused and existing model tests**

Run:

```bash
mise exec -- ruby bin/rails test test/models/publishable_translation_test.rb test/models/public_content_test.rb
```

Expected: PASS. Verify the idempotency test leaves both `published_at` and `updated_at` unchanged.

- [ ] **Step 5: Commit the domain interface**

```bash
git add app/models/concerns/publishable_translation.rb app/models/project_translation.rb app/models/post_translation.rb test/models/publishable_translation_test.rb
git commit -m "feat: centralize translation publication transitions"
```

---

### Task 2: Add Resourceful Publication Controls

**Files:**

- Modify: `config/routes.rb`
- Create: `app/controllers/admin/project_translations/publications_controller.rb`
- Create: `app/controllers/admin/post_translations/publications_controller.rb`
- Create: `app/views/admin/shared/_publication_controls.html.erb`
- Modify: `app/views/admin/projects/edit.html.erb`
- Modify: `app/views/admin/posts/edit.html.erb`
- Create: `app/javascript/controllers/schedule_time_controller.js`
- Create: `app/javascript/controllers/local_time_controller.js`
- Test: `test/requests/admin/project_translations/publications_test.rb`
- Test: `test/requests/admin/post_translations/publications_test.rb`

Do not modify the project/post strong parameters: Phase 4 already excludes `state`, `scheduled_at`, and `published_at`.

**Interfaces:**

- Consumes: Task 1 transitions, `Admin::BaseController` authentication, and existing edit pages.
- Produces: singular nested `publication` resources. `POST` publishes now, `PATCH` schedules, and `DELETE` returns a translation to draft. Schedule submissions use `publication[scheduled_at_local]` for the visible wall time and `publication[scheduled_at]` for the ISO 8601 instant generated by JavaScript.

- [ ] **Step 1: Write failing request tests**

Create `test/requests/admin/project_translations/publications_test.rb`:

```ruby
require "test_helper"

class Admin::ProjectTranslations::PublicationsTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(role: "Developer", translations_attributes: {
      "0" => { locale: "en", title: "English project", slug: "english-project", summary: "Summary", body_markdown: "Body" },
      "1" => { locale: "fr", title: "Projet français", slug: "projet-francais", summary: "Résumé", body_markdown: "Corps" }
    })
    @english = @project.translations.find_by!(locale: "en")
    @french = @project.translations.find_by!(locale: "fr")
  end

  test "requires a fully authenticated owner" do
    post admin_project_translation_publication_path(@english)
    assert_redirected_to new_admin_session_path
    assert_predicate @english.reload, :draft?
  end

  test "publishes only the selected translation with a 303 redirect" do
    sign_in_as_admin
    post admin_project_translation_publication_path(@english)
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_predicate @english.reload, :published?
    assert_predicate @french.reload, :draft?
  end

  test "rejects optional publication before English" do
    sign_in_as_admin
    post admin_project_translation_publication_path(@french)
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_equal "Publish the English translation first", flash[:alert]
    assert_predicate @french.reload, :draft?
  end

  test "schedules the exact ISO instant supplied by the browser" do
    sign_in_as_admin
    instant = 2.hours.from_now.change(sec: 0)
    patch admin_project_translation_publication_path(@english), params: {
      publication: { scheduled_at_local: "2026-09-05T09:30", scheduled_at: instant.iso8601 }
    }
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_equal instant, @english.reload.scheduled_at
  end

  test "uses explicitly labelled UTC input without JavaScript" do
    sign_in_as_admin
    patch admin_project_translation_publication_path(@english), params: {
      publication: { scheduled_at_local: 2.hours.from_now.utc.strftime("%Y-%m-%dT%H:%M"), scheduled_at: "" }
    }
    assert_predicate @english.reload, :scheduled?
  end

  test "malformed parameter structure receives the Rails 400 response" do
    sign_in_as_admin
    patch admin_project_translation_publication_path(@english), params: {}
    assert_response :bad_request
    assert_predicate @english.reload, :draft?
  end

  test "rejects malformed and past schedule values without changing state" do
    sign_in_as_admin
    [{ publication: { scheduled_at: "not-a-time" } },
     { publication: { scheduled_at: 1.minute.ago.iso8601 } }].each do |parameters|
      patch admin_project_translation_publication_path(@english), params: parameters
      assert_response :see_other
      assert_equal "Choose a future publication time", flash[:alert]
      assert_predicate @english.reload, :draft?
    end
  end

  test "unpublishes without changing the slug" do
    sign_in_as_admin
    travel_to 1.minute.ago do
      @english.publish
    end
    delete admin_project_translation_publication_path(@english)
    assert_response :see_other
    assert_predicate @english.reload, :draft?
    assert_equal "english-project", @english.slug
  end

  test "ordinary content updates cannot change publication state" do
    sign_in_as_admin
    patch admin_project_path(@project), params: { project: {
      role: @project.role,
      translations_attributes: {
        "0" => { id: @english.id, title: @english.title, slug: @english.slug,
          summary: @english.summary, body_markdown: @english.body_markdown, state: "published" }
      }
    } }

    assert_response :see_other
    assert_predicate @english.reload, :draft?
  end

  test "edit pages contain standalone publication forms" do
    sign_in_as_admin
    get edit_admin_project_path(@project)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@english, :publication)}"
    assert_select "form form", count: 0
  end
end
```

Create `test/requests/admin/post_translations/publications_test.rb` with the concrete post resource coverage:

```ruby
require "test_helper"

class Admin::PostTranslations::PublicationsTest < ActionDispatch::IntegrationTest
  setup do
    @post = Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "Post", slug: "post", excerpt: "Excerpt", body_markdown: "Body" }
    })
    @translation = @post.translations.first
    sign_in_as_admin
  end

  test "creates, updates, and destroys a post translation publication" do
    post admin_post_translation_publication_path(@translation)
    assert_redirected_to edit_admin_post_path(@post), status: :see_other
    assert_predicate @translation.reload, :published?

    patch admin_post_translation_publication_path(@translation), params: {
      publication: { scheduled_at: 2.hours.from_now.iso8601, scheduled_at_local: "" }
    }
    assert_response :see_other
    assert_predicate @translation.reload, :scheduled?

    delete admin_post_translation_publication_path(@translation)
    assert_response :see_other
    assert_predicate @translation.reload, :draft?

    get edit_admin_post_path(@post)
    assert_select "form form", count: 0
  end
end
```

- [ ] **Step 2: Verify the routes are missing**

Run: `mise exec -- ruby bin/rails test test/requests/admin/project_translations/publications_test.rb test/requests/admin/post_translations/publications_test.rb`

Expected: FAIL with an undefined publication route helper.

- [ ] **Step 3: Add singular nested publication resources**

Inside `namespace :admin`, add:

```ruby
resources :project_translations, only: [] do
  resource :publication, only: %i[create update destroy], module: :project_translations
end

resources :post_translations, only: [] do
  resource :publication, only: %i[create update destroy], module: :post_translations
end
```

- [ ] **Step 4: Add the concrete resource controllers**

Create `app/controllers/admin/project_translations/publications_controller.rb`:

```ruby
class Admin::ProjectTranslations::PublicationsController < Admin::BaseController
  before_action :set_translation

  def create
    @translation.publish
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was published", status: :see_other
  rescue PublishableTranslation::EnglishMustBePublished => error
    redirect_to edit_admin_project_path(@translation.project), alert: error.message, status: :see_other
  end

  def update
    @translation.schedule(at: scheduled_at)
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was scheduled", status: :see_other
  rescue PublishableTranslation::InvalidScheduleTime, ArgumentError
    redirect_to edit_admin_project_path(@translation.project), alert: "Choose a future publication time", status: :see_other
  end

  def destroy
    @translation.unpublish
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was unpublished", status: :see_other
  end

  private

  def set_translation
    @translation = ProjectTranslation.find(params[:project_translation_id])
  end

  def scheduled_at
    values = params.expect(publication: [:scheduled_at, :scheduled_at_local])
    if values[:scheduled_at].present?
      raise ArgumentError unless values[:scheduled_at].end_with?("Z")
      return Time.iso8601(values[:scheduled_at])
    end
    return Time.strptime(values[:scheduled_at_local], "%Y-%m-%dT%H:%M").utc if values[:scheduled_at_local].present?
  end
end
```

Create `app/controllers/admin/post_translations/publications_controller.rb`:

```ruby
class Admin::PostTranslations::PublicationsController < Admin::BaseController
  before_action :set_translation

  def create
    @translation.publish
    redirect_to edit_admin_post_path(@translation.post), notice: "#{@translation.title} was published", status: :see_other
  rescue PublishableTranslation::EnglishMustBePublished => error
    redirect_to edit_admin_post_path(@translation.post), alert: error.message, status: :see_other
  end

  def update
    @translation.schedule(at: scheduled_at)
    redirect_to edit_admin_post_path(@translation.post), notice: "#{@translation.title} was scheduled", status: :see_other
  rescue PublishableTranslation::InvalidScheduleTime, ArgumentError
    redirect_to edit_admin_post_path(@translation.post), alert: "Choose a future publication time", status: :see_other
  end

  def destroy
    @translation.unpublish
    redirect_to edit_admin_post_path(@translation.post), notice: "#{@translation.title} was unpublished", status: :see_other
  end

  private

  def set_translation
    @translation = PostTranslation.find(params[:post_translation_id])
  end

  def scheduled_at
    values = params.expect(publication: [:scheduled_at, :scheduled_at_local])
    if values[:scheduled_at].present?
      raise ArgumentError unless values[:scheduled_at].end_with?("Z")
      return Time.iso8601(values[:scheduled_at])
    end
    return Time.strptime(values[:scheduled_at_local], "%Y-%m-%dT%H:%M").utc if values[:scheduled_at_local].present?
  end
end
```

Keep this small duplication: extract a shared concern only when a third publishable translation type exists. Do not rescue `ActionController::ExpectedParameterMissing`; malformed parameter structures should receive Rails' normal 400 response.

- [ ] **Step 5: Add standalone publication controls**

Create `app/views/admin/shared/_publication_controls.html.erb`:

```erb
<%# locals: (translation:, publication_path:) %>

<section id="<%= dom_id(translation, :publication) %>" class="admin-card mt-6 grid gap-4"
  aria-label="<%= translation.locale.upcase %> publication">
  <h2 class="text-xl font-semibold"><%= translation.title %> (<%= translation.locale.upcase %>)</h2>
  <p><strong>Status:</strong> <%= translation.state.humanize %></p>

  <% if translation.scheduled_at %>
    <p>
      Scheduled for
      <time datetime="<%= translation.scheduled_at.iso8601 %>" data-controller="local-time">
        <%= translation.scheduled_at.utc.strftime("%Y-%m-%d %H:%M UTC") %>
      </time>
    </p>
  <% end %>

  <% unless translation.publishable? %>
    <p role="status">Publish the English translation before publishing this locale.</p>
  <% end %>

  <div class="flex flex-wrap gap-3">
    <% unless translation.published? %>
      <%= button_to "Publish now", publication_path,
        disabled: !translation.publishable?, class: "admin-action" %>
    <% end %>
    <% unless translation.draft? %>
      <%= button_to translation.scheduled? ? "Return to draft" : "Unpublish", publication_path,
        method: :delete, class: "admin-action",
        form: { data: { turbo_confirm: "Return #{translation.title} to draft?" } } %>
    <% end %>
  </div>

  <%= form_with url: publication_path, method: :patch, scope: :publication,
    data: { controller: "schedule-time", schedule_time_current_value: translation.scheduled_at&.iso8601 },
    class: "grid gap-2" do |form| %>
    <%= form.label :scheduled_at_local, "Publication time" %>
    <%= form.datetime_local_field :scheduled_at_local,
      value: translation.scheduled_at&.utc&.strftime("%Y-%m-%dT%H:%M"), required: true,
      data: { schedule_time_target: "input", action: "input->schedule-time#update" } %>
    <%= form.hidden_field :scheduled_at, value: "",
      data: { schedule_time_target: "instant" } %>
    <p class="text-sm opacity-70" data-schedule-time-target="hint">
      Times are UTC when JavaScript is unavailable.
    </p>
    <%= form.submit "Schedule", class: "admin-action" %>
  <% end %>
</section>
```

After the existing form render in both edit templates, render controls only for persisted translations:

```erb
<% @project.translations.select(&:persisted?).each do |translation| %>
  <%= render "admin/shared/publication_controls", translation:,
    publication_path: admin_project_translation_publication_path(translation) %>
<% end %>
```

In the post edit template use:

```erb
<% @post.translations.select(&:persisted?).each do |translation| %>
  <%= render "admin/shared/publication_controls", translation:,
    publication_path: admin_post_translation_publication_path(translation) %>
<% end %>
```

Do not place these controls in either `_translation_fields` partial because those partials are already inside the content form.

- [ ] **Step 6: Convert browser-local input to an exact instant**

Create `app/javascript/controllers/schedule_time_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "instant", "hint"];
  static values = { current: String };

  connect() {
    if (this.hasCurrentValue) {
      this.inputTarget.value = this.#localValue(new Date(this.currentValue));
    }
    this.inputTarget.min = this.#localValue(new Date(Date.now() + 60_000));
    this.hintTarget.textContent = `Times use ${Intl.DateTimeFormat().resolvedOptions().timeZone}.`;
    this.update();
  }

  update() {
    this.inputTarget.setCustomValidity("");
    this.instantTarget.value = "";
    if (!this.inputTarget.value) return;

    const instant = new Date(this.inputTarget.value);
    if (Number.isNaN(instant.valueOf()) || this.#localValue(instant) !== this.inputTarget.value) {
      this.inputTarget.setCustomValidity("Choose a valid local date and time.");
      return;
    }

    this.instantTarget.value = instant.toISOString();
  }

  #localValue(instant) {
    const local = new Date(instant.valueOf() - instant.getTimezoneOffset() * 60_000);
    return local.toISOString().slice(0, 16);
  }
}
```

Create `app/javascript/controllers/local_time_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const instant = new Date(this.element.dateTime);
    if (Number.isNaN(instant.valueOf())) return;

    this.element.textContent = instant.toLocaleString(undefined, {
      year: "numeric", month: "short", day: "numeric",
      hour: "2-digit", minute: "2-digit", timeZoneName: "short",
    });
  }
}
```

Repeated fall-back-hour values intentionally use the browser's earlier occurrence.

- [ ] **Step 7: Run request, route, and browser-import checks**

```bash
mise exec -- ruby bin/rails test test/requests/admin/project_translations/publications_test.rb test/requests/admin/post_translations/publications_test.rb
mise exec -- ruby bin/rails routes -g translation
mise exec -- ruby bin/importmap audit
```

Expected: request tests PASS, six publication routes appear (POST/PATCH/DELETE for each translation type), and the import audit passes.

- [ ] **Step 8: Commit the publication resources**

```bash
git add config/routes.rb app/controllers/admin/project_translations/publications_controller.rb app/controllers/admin/post_translations/publications_controller.rb app/views/admin/shared/_publication_controls.html.erb app/views/admin/projects/edit.html.erb app/views/admin/posts/edit.html.erb app/javascript/controllers/schedule_time_controller.js app/javascript/controllers/local_time_controller.js test/requests/admin/project_translations/publications_test.rb test/requests/admin/post_translations/publications_test.rb
git commit -m "feat: add translation publication controls"
```

---

### Task 3: Publish Due Translations Idempotently with Solid Queue

**Files:**

- Create: `app/jobs/publish_due_translations_job.rb`
- Modify or Create: `config/recurring.yml`
- Test: `test/jobs/publish_due_translations_job_test.rb`
- Test: `test/config/recurring_schedule_test.rb`

**Interfaces:**

- Consumes: Task 1 `due` and `publish` interfaces.
- Produces: argument-free `PublishDueTranslationsJob#perform` and production recurring key `publish_due_translations`.

- [ ] **Step 1: Write failing due-job tests**

Create `test/jobs/publish_due_translations_job_test.rb`:

```ruby
require "test_helper"

class PublishDueTranslationsJobTest < ActiveJob::TestCase
  test "publishes due English project and post translations but not future work" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project_due = create_project("due-project").translations.find_by!(locale: "en")
    post_due = create_post("due-post").translations.find_by!(locale: "en")
    future = create_post("future-post").translations.find_by!(locale: "en")
    project_due.update_columns(state: "scheduled", scheduled_at: now - 2.hours)
    post_due.update_columns(state: "scheduled", scheduled_at: now)
    future.update_columns(state: "scheduled", scheduled_at: now + 1.minute)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_equal now, project_due.reload.published_at
    assert_equal now, post_due.reload.published_at
    assert_predicate future.reload, :scheduled?
  end

  test "publishes overdue work on the first scan after downtime" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_project("catch-up").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: now - 3.days)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate translation.reload, :published?
    assert_equal now, translation.published_at
  end

  test "publishes due English before a due optional locale in the same scan" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("ordered", optional_locales: ["fr"])
    project.translations.update_all(state: "scheduled", scheduled_at: now - 1.minute)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate project.translations.find_by!(locale: "en"), :published?
    assert_predicate project.translations.find_by!(locale: "fr"), :published?
  end

  test "leaves blocked optional work scheduled and catches it up later" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("blocked", optional_locales: ["fr"])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    french.update_columns(state: "scheduled", scheduled_at: now - 1.hour)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end
    assert_predicate french.reload, :scheduled?

    travel_to now + 1.minute do
      english.publish
    end
    travel_to now + 2.minutes do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate french.reload, :published?
    assert_equal now + 2.minutes, french.published_at
  end

  test "a repeated scan preserves the first publication timestamp" do
    first_scan = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_post("idempotent").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: first_scan - 1.minute)

    travel_to first_scan do
      PublishDueTranslationsJob.perform_now
    end
    travel_to first_scan + 1.minute do
      PublishDueTranslationsJob.perform_now
    end

    assert_equal first_scan, translation.reload.published_at
  end

  private

  def create_project(slug, optional_locales: [])
    Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: (["en"] + optional_locales).map do |locale|
        { locale: locale, title: "#{slug} #{locale}", slug: "#{slug}-#{locale}", summary: "Summary", body_markdown: "Body" }
      end
    )
  end

  def create_post(slug)
    Post.create!(translations_attributes: [
      { locale: "en", title: slug, slug: slug, excerpt: "Excerpt", body_markdown: "Body" }
    ])
  end
end
```

- [ ] **Step 2: Run the job test and verify the job is missing**

Run:

```bash
mise exec -- ruby bin/rails test test/jobs/publish_due_translations_job_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublishDueTranslationsJob`.

- [ ] **Step 3: Implement the smallest retry-safe scan**

Create `app/jobs/publish_due_translations_job.rb`:

```ruby
class PublishDueTranslationsJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current
    models = [ProjectTranslation, PostTranslation]
    models.each { |model| publish_scope(model.due(now).where(locale: "en")) }
    models.each { |model| publish_scope(model.due(now).where.not(locale: "en")) }
  end

  private

  def publish_scope(scope)
    scope.find_each do |translation|
      begin
        translation.publish
      rescue PublishableTranslation::EnglishMustBePublished
        next
      end
    end
  end
end
```

Only the expected English-first domain error is skipped. Let database and programming errors escape so Solid Queue records and retries the job; rows published before a retry remain unchanged because `publish` is idempotent.

- [ ] **Step 4: Run the job tests**

Run:

```bash
mise exec -- ruby bin/rails test test/jobs/publish_due_translations_job_test.rb
```

Expected: PASS, including same-scan English-first ordering and overdue catch-up.

- [ ] **Step 5: Write the failing recurring-configuration test**

Create `test/config/recurring_schedule_test.rb`:

```ruby
require "test_helper"
require "yaml"

class RecurringScheduleTest < ActiveSupport::TestCase
  test "production scans for due translations every minute" do
    config = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    task = config.fetch("production").fetch("publish_due_translations")

    assert_equal "PublishDueTranslationsJob", task.fetch("class")
    assert_equal "every minute", task.fetch("schedule")
  end
end
```

- [ ] **Step 6: Run the configuration test and verify the key is absent**

Run:

```bash
mise exec -- ruby bin/rails test test/config/recurring_schedule_test.rb
```

Expected: FAIL with `KeyError: key not found: "publish_due_translations"` or `Errno::ENOENT` if Phase 1 has not generated the file.

- [ ] **Step 7: Configure Solid Queue recurrence**

Set `config/recurring.yml` to:

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  publish_due_translations:
    class: PublishDueTranslationsJob
    schedule: every minute
```

This keeps the Rails-generated cleanup task and adds one due-publication scan under the same `production:` mapping.

- [ ] **Step 8: Run both scheduling checks**

Run:

```bash
mise exec -- ruby bin/rails test test/jobs/publish_due_translations_job_test.rb test/config/recurring_schedule_test.rb
```

Expected: PASS.

- [ ] **Step 9: Commit scheduling and recurrence**

```bash
git add app/jobs/publish_due_translations_job.rb config/recurring.yml test/jobs/publish_due_translations_job_test.rb test/config/recurring_schedule_test.rb
git commit -m "feat: publish due translations with Solid Queue"
```

---

### Task 4: Show Actionable Publishing Work on the Dashboard

**Files:**

- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Test: `test/requests/admin/dashboard_test.rb`

**Interfaces:**

- Consumes: Task 1 `draft`, `upcoming`, `due`, `publishable?`, and `publication_parent` behavior.
- Produces: Dashboard collections `@draft_translations`, `@upcoming_translations`, and `@failed_publications`, each capped at ten records.

- [ ] **Step 1: Write a failing dashboard request test**

Append this test to the existing `Admin::DashboardTest` in `test/requests/admin/dashboard_test.rb`; keep its setup and count/navigation tests:

```ruby
test "shows drafts upcoming schedules and overdue English-blocked work" do
  now = Time.current
  project = Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: [
        { locale: "en", title: "Draft English", slug: "draft-english", summary: "Summary", body_markdown: "Body" },
        { locale: "fr", title: "Blocked French", slug: "blocked-french", summary: "Résumé", body_markdown: "Corps" },
        { locale: "vi", title: "Upcoming Vietnamese", slug: "upcoming-vietnamese", summary: "Tóm tắt", body_markdown: "Nội dung" }
      ]
    )
  project.translations.find_by!(locale: "fr").update_columns(state: "scheduled", scheduled_at: now - 1.hour)
  project.translations.find_by!(locale: "vi").update_columns(state: "scheduled", scheduled_at: now + 1.hour)
  published_post = Post.create!(translations_attributes: [
    { locale: "en", title: "Published Post", slug: "published-post", excerpt: "Excerpt", body_markdown: "Body" }
  ])
  travel_to now - 1.day do
    published_post.translations.first.publish
  end

  get admin_root_path

  assert_response :success
  assert_select "#draft-content", text: /Draft English/
  assert_select "#upcoming-publications", text: /Upcoming Vietnamese/
  assert_select "#failed-publications", text: /Blocked French/
  assert_no_match(/Published Post/, response.body)
end

test "caps each publishing summary at ten records" do
  11.times do |index|
    Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "Draft #{index}", slug: "draft-#{index}", excerpt: "Excerpt", body_markdown: "Body" }
    })
  end

  get admin_root_path

  assert_select "#draft-content li", count: 10
end
```

- [ ] **Step 2: Run the dashboard test and verify the summaries are absent**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/dashboard_test.rb
```

Expected: FAIL because the three section IDs or record titles are missing.

- [ ] **Step 3: Add exact cross-model dashboard queries**

Replace the Phase 4 `show` action in `app/controllers/admin/dashboard_controller.rb`, preserving its count queries, with:

```ruby
class Admin::DashboardController < Admin::BaseController
  TRANSLATION_MODELS = [ProjectTranslation, PostTranslation].freeze

  def show
    @project_count = Project.count
    @post_count = Post.count
    @tag_count = Tag.count
    now = Time.current

    @draft_translations = TRANSLATION_MODELS
      .flat_map { |model| model.draft.order(updated_at: :desc).limit(10).to_a }
      .sort_by(&:updated_at)
      .reverse
      .first(10)

    @upcoming_translations = TRANSLATION_MODELS
      .flat_map { |model| model.upcoming(now).order(:scheduled_at).limit(10).to_a }
      .sort_by(&:scheduled_at)
      .first(10)

    @failed_publications = TRANSLATION_MODELS
      .flat_map { |model| model.due(now).where.not(locale: "en").order(:scheduled_at).to_a }
      .reject(&:publishable?)
      .sort_by(&:scheduled_at)
      .first(10)
  end
end
```

The final collection is the expected actionable failure mode: an overdue optional locale cannot publish because English is still unpublished. Unexpected job exceptions remain visible through Solid Queue retry/failure handling and are not duplicated into an application table.

- [ ] **Step 4: Render the three mobile-first summaries**

Append these publishing sections after the existing count cards and before the closing `<main>` in `app/views/admin/dashboard/show.html.erb`:

```erb
  <section id="draft-content" aria-labelledby="draft-content-heading">
    <h2 id="draft-content-heading" class="text-xl font-semibold">Draft content</h2>
    <% if @draft_translations.any? %>
      <ul class="mt-3 space-y-3">
        <% @draft_translations.each do |translation| %>
          <li>
            <%= link_to "#{translation.title} (#{translation.locale.upcase})",
              edit_polymorphic_path([:admin, translation.publication_parent]),
              class: "inline-flex min-h-11 items-center" %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="mt-3">No draft content.</p>
    <% end %>
  </section>

  <section id="upcoming-publications" aria-labelledby="upcoming-publications-heading">
    <h2 id="upcoming-publications-heading" class="text-xl font-semibold">Upcoming publications</h2>
    <% if @upcoming_translations.any? %>
      <ul class="mt-3 space-y-3">
        <% @upcoming_translations.each do |translation| %>
          <li>
            <%= link_to "#{translation.title} (#{translation.locale.upcase})",
              edit_polymorphic_path([:admin, translation.publication_parent]),
              class: "inline-flex min-h-11 items-center" %>
            <time datetime="<%= translation.scheduled_at.iso8601 %>" data-controller="local-time">
              <%= translation.scheduled_at.utc.strftime("%Y-%m-%d %H:%M UTC") %>
            </time>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="mt-3">No upcoming publications.</p>
    <% end %>
  </section>

  <section id="failed-publications" aria-labelledby="failed-publications-heading">
    <h2 id="failed-publications-heading" class="text-xl font-semibold">Failed publication work</h2>
    <% if @failed_publications.any? %>
      <p class="mt-3">These overdue translations are waiting for their English translation to be published.</p>
      <ul class="mt-3 space-y-3">
        <% @failed_publications.each do |translation| %>
          <li>
            <%= link_to "#{translation.title} (#{translation.locale.upcase})",
              edit_polymorphic_path([:admin, translation.publication_parent]),
              class: "inline-flex min-h-11 items-center" %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="mt-3">No failed publication work.</p>
    <% end %>
  </section>
```

Phase 6 adds unread-message and failed-delivery sections after these sections; do not create empty contact queries in Phase 5.

- [ ] **Step 5: Run dashboard and publication tests**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/dashboard_test.rb test/requests/admin/project_translations/publications_test.rb test/requests/admin/post_translations/publications_test.rb test/models/publishable_translation_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit actionable dashboard summaries**

```bash
git add app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb test/requests/admin/dashboard_test.rb
git commit -m "feat: show publishing work on admin dashboard"
```

---

### Task 5: Prove the Owner Workflow and Public Isolation

**Files:**

- Create: `test/system/admin_publishing_test.rb`
- Modify: `test/integration/public_content_test.rb`

**Interfaces:**

- Consumes: Phase 2 public project route, Phase 3 password/TOTP flow, Phase 4 editor, and Tasks 1–4.
- Produces: One release-boundary system check covering English-first UI, independent locale publication, scheduling, due catch-up, and public visibility.

- [ ] **Step 1: Write the failing end-to-end system test**

Create `test/system/admin_publishing_test.rb`:

```ruby
require "application_system_test_case"

class AdminPublishingTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActionView::RecordIdentifier

  test "owner publishes locales independently and a due schedule becomes public" do
    project = Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: [
        { locale: "en", title: "English Case Study", slug: "english-case-study", summary: "Summary", body_markdown: "English body" },
        { locale: "fr", title: "Étude de cas", slug: "etude-de-cas", summary: "Résumé", body_markdown: "Corps français" },
        { locale: "vi", title: "Dự án", slug: "du-an", summary: "Tóm tắt", body_markdown: "Nội dung" }
      ]
    )
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    vietnamese = project.translations.find_by!(locale: "vi")

    sign_in_owner
    page.current_window.resize_to(320, 700)
    visit edit_admin_project_path(project)
    within "##{dom_id(french, :publication)}" do
      assert_button "Publish now", disabled: true
      assert_text "Publish the English translation before publishing this locale."
    end

    within "##{dom_id(english, :publication)}" do
      click_on "Publish now"
    end
    assert_text "English Case Study was published"

    within "##{dom_id(french, :publication)}" do
      click_on "Publish now"
    end
    assert_text "Étude de cas was published"

    visit "/fr/projects/#{french.slug}"
    assert_text "Étude de cas"

    visit edit_admin_project_path(project)
    within "##{dom_id(vietnamese, :publication)}" do
      fill_in "Publication time", with: 1.hour.from_now.change(sec: 0).strftime("%Y-%m-%dT%H:%M")
      click_on "Schedule"
    end
    assert_text "Dự án was scheduled"

    travel_to vietnamese.reload.scheduled_at + 1.minute do
      PublishDueTranslationsJob.perform_now
    end

    visit "/vi/projects/#{vietnamese.slug}"
    assert_text "Dự án"
    assert_text "Nội dung"
  end
end
```

- [ ] **Step 2: Add exact public-response coverage**

Append this test to `PublicContentRequestTest` in `test/integration/public_content_test.rb`:

```ruby
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

  due_at = 1.hour.from_now
  vietnamese.schedule(at: due_at)
  travel_to due_at do
    PublishDueTranslationsJob.perform_now
  end
  get "/vi/projects/#{vietnamese.slug}"
  assert_response :success

  french.unpublish
  get "/fr/projects/#{french.slug}"
  assert_response :not_found
end
```

- [ ] **Step 3: Run the end-to-end and public tests**

Run:

```bash
mise exec -- ruby bin/rails test test/integration/public_content_test.rb
mise exec -- ruby bin/rails test test/system/admin_publishing_test.rb
```

Expected: PASS. The system test uses the accepted `sign_in_owner` helper and singleton fixture; do not create a second `AdminUser` or add a test-only authentication route.

- [ ] **Step 4: Commit the acceptance workflow**

```bash
git add test/system/admin_publishing_test.rb test/integration/public_content_test.rb
git commit -m "test: cover localized publishing workflow"
```

---

## Phase Verification and Acceptance

- [ ] **Run every Phase 5 focused test together**

```bash
mise exec -- ruby bin/rails test test/models/publishable_translation_test.rb test/requests/admin/project_translations/publications_test.rb test/requests/admin/post_translations/publications_test.rb test/jobs/publish_due_translations_job_test.rb test/config/recurring_schedule_test.rb test/requests/admin/dashboard_test.rb test/integration/public_content_test.rb
mise exec -- ruby bin/rails test test/system/admin_publishing_test.rb
```

Expected: PASS with zero failures and zero errors.

- [ ] **Run the complete application suites required at the phase boundary**

```bash
mise exec -- ruby bin/rails test
mise exec -- ruby bin/rails test:system
mise exec -- ruby bin/rails zeitwerk:check
mise exec -- ruby bin/importmap audit
```

Expected: both test suites, Zeitwerk check, and import audit PASS.

- [ ] **Verify recurrence is loadable by Solid Queue**

```bash
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production mise exec -- ruby bin/rails runner 'task = YAML.safe_load_file(Rails.root.join("config/recurring.yml")).fetch("production").fetch("publish_due_translations"); abort unless task == {"class" => "PublishDueTranslationsJob", "schedule" => "every minute"}; puts task'
```

Expected output:

```text
{"class"=>"PublishDueTranslationsJob", "schedule"=>"every minute"}
```

- [ ] **Manually demonstrate the usable result**

```bash
bin/dev
```

At 320 CSS pixels and at a desktop width:

1. Sign in with password and TOTP.
2. Open a project containing English and French translations.
3. Confirm French Publish is disabled while English is draft.
4. Publish English, then publish French; verify only those locale URLs are public.
5. In a non-UTC browser, schedule Vietnamese one minute ahead; verify the displayed zone is local and the locale remains unavailable before the due instant.
6. Run `mise exec -- ruby bin/rails runner 'PublishDueTranslationsJob.perform_now'`; verify Vietnamese becomes public. Disable JavaScript once and confirm the schedule form clearly falls back to UTC.
7. Unpublish French; verify its slug is unchanged and its public URL returns 404.
8. Open `/admin`; verify draft, upcoming, and blocked-overdue records appear under the correct actionable headings at 320 CSS pixels, desktop width, and 200% zoom.

- [ ] **Inspect the final diff and commit state**

```bash
git status --short
git log --oneline -5
git diff --check HEAD~5..HEAD
```

Expected: no uncommitted Phase 5 files, the five commits from this plan are present in order, and `git diff --check` prints nothing.

- [ ] **Tag the accepted phase only after all checks and the demonstration pass**

```bash
git tag -a portfolio-v4-phase-5 -m "Portfolio v4 phase 5: publishing and scheduling"
```

## Risks and Verification Points

- **Concurrent or repeated scans:** `with_lock` plus the early return for published rows prevents timestamp rewrites. The model idempotency test and repeated-job test are the verification points.
- **Optional locale due in the same minute as English:** the job scans due English rows first, then optional rows. The ordering job test proves both publish in one run.
- **Optional locale blocked after downtime:** the job leaves the row scheduled, the dashboard surfaces it, and the next scan catches it after English publishes. The blocked/catch-up test covers this path.
- **Unexpected publication failure:** only `EnglishMustBePublished` is swallowed. Every other exception reaches Solid Queue for retry rather than silently losing work.
- **State bypass through ordinary edit forms:** project/post strong parameters exclude `state`, `scheduled_at`, and `published_at`; request tests exercise only explicit endpoints.
- **Public leakage:** existing `publicly_visible(locale:)` scopes remain the sole public read path. The system test verifies one published locale cannot expose a draft or scheduled sibling.
- **Operational cadence:** one-minute polling is intentional for a personal site and requires no extra dependency. Increase complexity only if measured publishing latency requires it.
