# Portfolio v4 Publishing and Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner publish, unpublish, and schedule each project or post translation independently while enforcing English-first publication and catching up overdue work safely.

**Architecture:** A shared `PublishableTranslation` model concern owns every state transition and query scope used by both translation models. Explicit authenticated admin endpoints invoke that interface; one recurring Solid Queue job scans English records before optional locales so retries and downtime catch-up are idempotent. The existing dashboard reads the same scopes and treats overdue optional translations blocked by an unpublished English sibling as failed publication work requiring owner action.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Active Record, Active Job, Solid Queue, SQLite, Hotwire/Turbo, Tailwind CSS, Minitest, Capybara

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

**Parent plan:** `docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md` — Phase 5 contract is immutable.

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
- `sign_in_as_admin` is the Phase 3 request-test helper; the Phase 3 system flow uses `new_admin_session_path`, fields `Email` and `Password`, then `admin_totp_challenge_path` with field `Authentication code`.
- Phase 4 provides `edit_admin_project_path`, `edit_admin_post_path`, project/post translation tab partials, and the protected `Admin::DashboardController#show` at `admin_root_path`.

If an earlier phase has not produced one of these contracts, stop and finish that phase rather than adding compatibility code here.

## File Map

| Path                                                                 | Responsibility                                                                           |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `app/models/concerns/publishable_translation.rb`                     | Shared transition methods, English-first guard, and due/upcoming scopes                  |
| `app/models/project_translation.rb`                                  | Includes the concern and returns its `Project` publication parent                        |
| `app/models/post_translation.rb`                                     | Includes the concern and returns its `Post` publication parent                           |
| `config/routes.rb`                                                   | Six explicit member actions: publish, schedule, and unpublish for both translation types |
| `app/controllers/admin/translation_publications_controller.rb`       | Authenticated transition endpoint with a fixed type allowlist                            |
| `app/views/admin/shared/_publication_controls.html.erb`              | Per-locale state, native datetime input, and explicit action buttons                     |
| `app/views/admin/projects/_translation_fields.html.erb`              | Renders controls for each persisted project translation                                  |
| `app/views/admin/posts/_translation_fields.html.erb`                 | Renders controls for each persisted post translation                                     |
| `app/controllers/admin/projects_controller.rb`                       | Keeps transition columns out of general nested update parameters                         |
| `app/controllers/admin/posts_controller.rb`                          | Keeps transition columns out of general nested update parameters                         |
| `app/jobs/publish_due_translations_job.rb`                           | Idempotent English-first scan over both translation models                               |
| `config/recurring.yml`                                               | Runs the due scan every minute in production                                             |
| `app/controllers/admin/dashboard_controller.rb`                      | Queries draft, upcoming, and blocked-overdue translations                                |
| `app/views/admin/dashboard/show.html.erb`                            | Extends the existing dashboard with actionable publishing summaries                      |
| `test/models/publishable_translation_test.rb`                        | Shared state-transition, validation, and idempotency coverage                            |
| `test/controllers/admin/translation_publications_controller_test.rb` | Authentication and explicit-action request coverage                                      |
| `test/jobs/publish_due_translations_job_test.rb`                     | Due scan, catch-up, ordering, retry, and idempotency coverage                            |
| `test/config/recurring_schedule_test.rb`                             | Locks the recurring production schedule to the intended job                              |
| `test/controllers/admin/dashboard_controller_test.rb`                | Dashboard inclusion/exclusion coverage                                                   |
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
  def publish!(at: Time.current) = self

  # Returns self; at must be later than Time.current.
  def schedule!(at:) = self

  # Returns self and preserves slug.
  def unpublish! = self

  # Returns Project or Post.
  def publication_parent

  # Returns true for English, or when the parent's English translation is published.
  def publishable_now?
end

class PublishDueTranslationsJob < ApplicationJob
  # The optional argument exists for deterministic tests; recurring execution supplies none.
  def perform(now = Time.current)
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
- Produces: `due`, `upcoming`, `publish!`, `schedule!`, `unpublish!`, `publication_parent`, and `publishable_now?` exactly as documented above.

- [ ] **Step 1: Write the failing model tests**

Create `test/models/publishable_translation_test.rb`:

```ruby
require "test_helper"

class PublishableTranslationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "publishing English records the supplied time and clears its schedule" do
    translation = create_project.translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: 1.hour.ago)
    publication_time = Time.zone.local(2026, 9, 2, 12, 0, 0)

    assert_same translation, translation.publish!(at: publication_time)

    translation.reload
    assert_predicate translation, :published?
    assert_equal publication_time, translation.published_at
    assert_nil translation.scheduled_at
  end

  test "non-English publication requires a published English sibling" do
    project = create_project(optional_locales: ["fr"])
    french = project.translations.find_by!(locale: "fr")

    error = assert_raises(PublishableTranslation::EnglishMustBePublished) do
      french.publish!(at: Time.current)
    end

    assert_equal "Publish the English translation first", error.message
    assert_predicate french.reload, :draft?
    assert_nil french.published_at
  end

  test "non-English publication succeeds after English publication" do
    project = create_project(optional_locales: ["fr"])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")

    english.publish!(at: 2.minutes.ago)
    french.publish!(at: 1.minute.ago)

    assert_predicate french.reload, :published?
  end

  test "scheduling uses a future time and clears an old publication time" do
    translation = create_post.translations.find_by!(locale: "en")
    translation.publish!(at: 1.day.ago)
    scheduled_time = 2.hours.from_now

    assert_same translation, translation.schedule!(at: scheduled_time)

    translation.reload
    assert_predicate translation, :scheduled?
    assert_equal scheduled_time, translation.scheduled_at
    assert_nil translation.published_at
  end

  test "scheduling rejects blank or non-future times without changing the row" do
    translation = create_post.translations.find_by!(locale: "en")

    [nil, 1.minute.ago].each do |invalid_time|
      assert_raises(PublishableTranslation::InvalidScheduleTime) do
        translation.schedule!(at: invalid_time)
      end
    end

    assert_predicate translation.reload, :draft?
    assert_nil translation.scheduled_at
  end

  test "unpublishing returns to draft and preserves the localized slug" do
    translation = create_project.translations.find_by!(locale: "en")
    original_slug = translation.slug
    translation.publish!(at: 1.minute.ago)

    assert_same translation, translation.unpublish!

    translation.reload
    assert_predicate translation, :draft?
    assert_equal original_slug, translation.slug
    assert_nil translation.scheduled_at
    assert_nil translation.published_at
  end

  test "publishing an already-published translation performs no second write" do
    translation = create_project.translations.find_by!(locale: "en")
    first_time = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation.publish!(at: first_time)
    first_updated_at = translation.reload.updated_at

    travel 1.hour do
      assert_no_changes -> { translation.reload.attributes.slice("published_at", "updated_at") } do
        translation.publish!(at: Time.current)
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
bin/rails test test/models/publishable_translation_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublishableTranslation` or `NoMethodError` for `publish!`.

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

    validates :scheduled_at, presence: true, if: :scheduled?
    validates :published_at, presence: true, if: :published?
    validate :english_is_published_before_optional_locale, if: :publishing_optional_locale?
  end

  def publish!(at: Time.current)
    with_lock do
      return self if published?
      raise EnglishMustBePublished, "Publish the English translation first" unless publishable_now?

      update!(state: :published, scheduled_at: nil, published_at: at)
    end

    self
  end

  def schedule!(at:)
    raise InvalidScheduleTime, "Choose a future publication time" unless at && at > Time.current

    with_lock do
      update!(state: :scheduled, scheduled_at: at, published_at: nil)
    end

    self
  end

  def unpublish!
    with_lock do
      return self if draft?

      update!(state: :draft, scheduled_at: nil, published_at: nil)
    end

    self
  end

  def publishable_now?
    locale == "en" || publication_parent.translations.published.exists?(locale: "en")
  end

  private

  def publishing_optional_locale?
    locale != "en" && published? && will_save_change_to_state?
  end

  def english_is_published_before_optional_locale
    errors.add(:state, "requires the English translation to be published first") unless publishable_now?
  end
end
```

In `app/models/project_translation.rb`, include the concern directly below the class declaration and add the parent method:

```ruby
class ProjectTranslation < ApplicationRecord
  include PublishableTranslation

  belongs_to :project

  def publication_parent
    project
  end
end
```

Preserve every Phase 2 validation, enum, callback, and scope already in the class; do not duplicate the enum in the concern.

In `app/models/post_translation.rb`, make the equivalent focused change:

```ruby
class PostTranslation < ApplicationRecord
  include PublishableTranslation

  belongs_to :post

  def publication_parent
    post
  end
end
```

Preserve every existing post translation rule around this addition.

- [ ] **Step 4: Run focused and existing model tests**

Run:

```bash
bin/rails test test/models/publishable_translation_test.rb test/models/public_content_test.rb
```

Expected: PASS. Verify the idempotency test leaves both `published_at` and `updated_at` unchanged.

- [ ] **Step 5: Commit the domain interface**

```bash
git add app/models/concerns/publishable_translation.rb app/models/project_translation.rb app/models/post_translation.rb test/models/publishable_translation_test.rb
git commit -m "feat: centralize translation publication transitions"
```

---

### Task 2: Add Explicit Authenticated Locale Actions

**Files:**

- Modify: `config/routes.rb`
- Create: `app/controllers/admin/translation_publications_controller.rb`
- Create: `app/views/admin/shared/_publication_controls.html.erb`
- Modify: `app/views/admin/projects/_translation_fields.html.erb`
- Modify: `app/views/admin/posts/_translation_fields.html.erb`
- Modify: `app/controllers/admin/projects_controller.rb`
- Modify: `app/controllers/admin/posts_controller.rb`
- Test: `test/controllers/admin/translation_publications_controller_test.rb`

**Interfaces:**

- Consumes: Task 1 transitions and Phase 3 `Admin::BaseController` authentication.
- Produces: `publish_admin_project_translation_path`, `schedule_admin_project_translation_path`, `unpublish_admin_project_translation_path`, and equivalent post translation paths.

- [ ] **Step 1: Write failing request tests for authentication and all three actions**

Create `test/controllers/admin/translation_publications_controller_test.rb`:

```ruby
require "test_helper"

class Admin::TranslationPublicationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @project = Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: [
        { locale: "en", title: "English project", slug: "english-project", summary: "Summary", body_markdown: "Body" },
        { locale: "fr", title: "Projet français", slug: "projet-francais", summary: "Résumé", body_markdown: "Corps" }
      ]
    )
    @english = @project.translations.find_by!(locale: "en")
    @french = @project.translations.find_by!(locale: "fr")
  end

  test "an unauthenticated owner cannot invoke a publication action" do
    patch publish_admin_project_translation_path(@english)

    assert_redirected_to new_admin_session_path
    assert_predicate @english.reload, :draft?
  end

  test "publish changes only the selected persisted translation" do
    sign_in_as_admin

    patch publish_admin_project_translation_path(@english)

    assert_redirected_to edit_admin_project_path(@project)
    assert_equal "English project was published", flash[:notice]
    assert_predicate @english.reload, :published?
    assert_predicate @french.reload, :draft?
  end

  test "publish reports the English-first rule without changing French" do
    sign_in_as_admin

    patch publish_admin_project_translation_path(@french)

    assert_redirected_to edit_admin_project_path(@project)
    assert_equal "Publish the English translation first", flash[:alert]
    assert_predicate @french.reload, :draft?
  end

  test "schedule parses the owner time zone and schedules the selected translation" do
    sign_in_as_admin
    scheduled_time = 2.hours.from_now.change(sec: 0)

    patch schedule_admin_project_translation_path(@english), params: {
      publication: { scheduled_at: scheduled_time.strftime("%Y-%m-%dT%H:%M") }
    }

    assert_redirected_to edit_admin_project_path(@project)
    assert_equal "English project was scheduled", flash[:notice]
    assert_equal scheduled_time, @english.reload.scheduled_at
    assert_predicate @english, :scheduled?
  end

  test "schedule rejects a blank time without changing state" do
    sign_in_as_admin

    patch schedule_admin_project_translation_path(@english), params: {
      publication: { scheduled_at: "" }
    }

    assert_redirected_to edit_admin_project_path(@project)
    assert_equal "Choose a future publication time", flash[:alert]
    assert_predicate @english.reload, :draft?
  end

  test "unpublish preserves the selected translation slug" do
    sign_in_as_admin
    @english.publish!(at: 1.minute.ago)

    patch unpublish_admin_project_translation_path(@english)

    assert_redirected_to edit_admin_project_path(@project)
    assert_equal "English project was unpublished", flash[:notice]
    assert_predicate @english.reload, :draft?
    assert_equal "english-project", @english.slug
  end

  test "post translation routes use the same allowlisted controller" do
    sign_in_as_admin
    post_record = Post.create!(translations_attributes: [
      { locale: "en", title: "English post", slug: "english-post", excerpt: "Excerpt", body_markdown: "Body" }
    ])
    translation = post_record.translations.find_by!(locale: "en")

    patch publish_admin_post_translation_path(translation)

    assert_redirected_to edit_admin_post_path(post_record)
    assert_predicate translation.reload, :published?
  end
end
```

- [ ] **Step 2: Run the request tests and verify the routes are absent**

Run:

```bash
bin/rails test test/controllers/admin/translation_publications_controller_test.rb
```

Expected: FAIL with an undefined route helper such as `publish_admin_project_translation_path`.

- [ ] **Step 3: Add fixed routes and the allowlisted controller**

Inside the existing `namespace :admin do` block in `config/routes.rb`, add exactly these routes:

```ruby
resources :project_translations, only: [] do
  member do
    patch :publish, to: "translation_publications#publish",
      defaults: { translation_type: "ProjectTranslation" }
    patch :schedule, to: "translation_publications#schedule",
      defaults: { translation_type: "ProjectTranslation" }
    patch :unpublish, to: "translation_publications#unpublish",
      defaults: { translation_type: "ProjectTranslation" }
  end
end

resources :post_translations, only: [] do
  member do
    patch :publish, to: "translation_publications#publish",
      defaults: { translation_type: "PostTranslation" }
    patch :schedule, to: "translation_publications#schedule",
      defaults: { translation_type: "PostTranslation" }
    patch :unpublish, to: "translation_publications#unpublish",
      defaults: { translation_type: "PostTranslation" }
  end
end
```

Create `app/controllers/admin/translation_publications_controller.rb`:

```ruby
class Admin::TranslationPublicationsController < Admin::BaseController
  TRANSLATION_CLASSES = {
    "ProjectTranslation" => ProjectTranslation,
    "PostTranslation" => PostTranslation
  }.freeze

  before_action :set_translation

  def publish
    @translation.publish!
    redirect_to edit_path, notice: "#{@translation.title} was published"
  rescue PublishableTranslation::EnglishMustBePublished => error
    redirect_to edit_path, alert: error.message
  end

  def schedule
    @translation.schedule!(at: parsed_scheduled_at)
    redirect_to edit_path, notice: "#{@translation.title} was scheduled"
  rescue PublishableTranslation::InvalidScheduleTime, ArgumentError => error
    message = error.is_a?(PublishableTranslation::InvalidScheduleTime) ? error.message : "Choose a future publication time"
    redirect_to edit_path, alert: message
  end

  def unpublish
    @translation.unpublish!
    redirect_to edit_path, notice: "#{@translation.title} was unpublished"
  end

  private

  def set_translation
    TRANSLATION_CLASSES.fetch(params[:translation_type]).find(params[:id]).then do |translation|
      @translation = translation
    end
  end

  def parsed_scheduled_at
    value = params.require(:publication).permit(:scheduled_at).fetch(:scheduled_at)
    value.present? ? Time.zone.parse(value) : nil
  end

  def edit_path
    case @translation
    when ProjectTranslation
      edit_admin_project_path(@translation.project)
    when PostTranslation
      edit_admin_post_path(@translation.post)
    end
  end
end
```

The route defaults, not user-supplied class names, choose between two constants. Do not use `constantize`.

- [ ] **Step 4: Keep state fields out of general content updates**

In `Admin::ProjectsController`, ensure the nested translation allowlist is exactly the authored fields plus nested-record bookkeeping:

```ruby
translations_attributes: %i[id locale title slug summary body_markdown _destroy]
```

In `Admin::PostsController`, use:

```ruby
translations_attributes: %i[id locale title slug excerpt body_markdown _destroy]
```

Remove `state`, `scheduled_at`, and `published_at` if Phase 4 permitted them. These columns may change only through the Task 1 interface.

- [ ] **Step 5: Add per-locale native controls**

Create `app/views/admin/shared/_publication_controls.html.erb`:

```erb
<% model_key = translation.model_name.singular %>
<% publish_path = public_send("publish_admin_#{model_key}_path", translation) %>
<% schedule_path = public_send("schedule_admin_#{model_key}_path", translation) %>
<% unpublish_path = public_send("unpublish_admin_#{model_key}_path", translation) %>

<section id="<%= dom_id(translation, :publication) %>" class="mt-6 space-y-3 border-t pt-4" aria-label="<%= translation.locale.upcase %> publication">
  <p><strong>Status:</strong> <%= translation.state.humanize %></p>

  <% unless translation.publishable_now? %>
    <p class="text-sm" role="status">Publish the English translation before publishing this locale.</p>
  <% end %>

  <div class="flex flex-wrap gap-3">
    <%= button_to "Publish", publish_path, method: :patch,
      disabled: !translation.publishable_now?,
      class: "min-h-11 px-4 py-2" %>

    <% unless translation.draft? %>
      <%= button_to "Unpublish", unpublish_path, method: :patch,
        form: { data: { turbo_confirm: "Unpublish #{translation.title}?" } },
        class: "min-h-11 px-4 py-2" %>
    <% end %>
  </div>

  <%= form_with url: schedule_path, method: :patch, scope: :publication, class: "space-y-2" do |form| %>
    <%= form.label :scheduled_at, "Schedule #{translation.locale} publication" %>
    <%= form.datetime_local_field :scheduled_at,
      value: translation.scheduled_at&.strftime("%Y-%m-%dT%H:%M"),
      min: 1.minute.from_now.strftime("%Y-%m-%dT%H:%M"),
      required: true,
      class: "min-h-11" %>
    <%= form.submit "Schedule", class: "min-h-11 px-4 py-2" %>
  <% end %>
</section>
```

At the end of the persisted-record branch in both `app/views/admin/projects/_translation_fields.html.erb` and `app/views/admin/posts/_translation_fields.html.erb`, render:

```erb
<%= render "admin/shared/publication_controls", translation: translation_form.object if translation_form.object.persisted? %>
```

Use the existing Phase 4 local variable `translation_form`; do not render transition controls for a translation that has not been saved yet.

- [ ] **Step 6: Run route and request verification**

Run:

```bash
bin/rails routes -g 'admin_.*translation' | grep -E 'publish|schedule|unpublish'
bin/rails test test/controllers/admin/translation_publications_controller_test.rb
```

Expected: six PATCH routes are printed and all request tests PASS.

- [ ] **Step 7: Commit the explicit owner actions**

```bash
git add config/routes.rb app/controllers/admin/translation_publications_controller.rb app/controllers/admin/projects_controller.rb app/controllers/admin/posts_controller.rb app/views/admin/shared/_publication_controls.html.erb app/views/admin/projects/_translation_fields.html.erb app/views/admin/posts/_translation_fields.html.erb test/controllers/admin/translation_publications_controller_test.rb
git commit -m "feat: add explicit translation publication actions"
```

---

### Task 3: Publish Due Translations Idempotently with Solid Queue

**Files:**

- Create: `app/jobs/publish_due_translations_job.rb`
- Modify or Create: `config/recurring.yml`
- Test: `test/jobs/publish_due_translations_job_test.rb`
- Test: `test/config/recurring_schedule_test.rb`

**Interfaces:**

- Consumes: Task 1 `due` and `publish!` interfaces.
- Produces: `PublishDueTranslationsJob#perform(now = Time.current)` and production recurring key `publish_due_translations`.

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

    PublishDueTranslationsJob.perform_now(now)

    assert_equal now, project_due.reload.published_at
    assert_equal now, post_due.reload.published_at
    assert_predicate future.reload, :scheduled?
  end

  test "publishes overdue work on the first scan after downtime" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_project("catch-up").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: now - 3.days)

    PublishDueTranslationsJob.perform_now(now)

    assert_predicate translation.reload, :published?
    assert_equal now, translation.published_at
  end

  test "publishes due English before a due optional locale in the same scan" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("ordered", optional_locales: ["fr"])
    project.translations.update_all(state: "scheduled", scheduled_at: now - 1.minute)

    PublishDueTranslationsJob.perform_now(now)

    assert_predicate project.translations.find_by!(locale: "en"), :published?
    assert_predicate project.translations.find_by!(locale: "fr"), :published?
  end

  test "leaves blocked optional work scheduled and catches it up later" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("blocked", optional_locales: ["fr"])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    french.update_columns(state: "scheduled", scheduled_at: now - 1.hour)

    PublishDueTranslationsJob.perform_now(now)
    assert_predicate french.reload, :scheduled?

    english.publish!(at: now + 1.minute)
    PublishDueTranslationsJob.perform_now(now + 2.minutes)

    assert_predicate french.reload, :published?
    assert_equal now + 2.minutes, french.published_at
  end

  test "a repeated scan preserves the first publication timestamp" do
    first_scan = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_post("idempotent").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: first_scan - 1.minute)

    PublishDueTranslationsJob.perform_now(first_scan)
    PublishDueTranslationsJob.perform_now(first_scan + 1.minute)

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
bin/rails test test/jobs/publish_due_translations_job_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublishDueTranslationsJob`.

- [ ] **Step 3: Implement the smallest retry-safe scan**

Create `app/jobs/publish_due_translations_job.rb`:

```ruby
class PublishDueTranslationsJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    [ProjectTranslation, PostTranslation].each do |model|
      publish_scope(model.due(now).where(locale: "en"), at: now)
      publish_scope(model.due(now).where.not(locale: "en"), at: now)
    end
  end

  private

  def publish_scope(scope, at:)
    scope.find_each do |translation|
      translation.publish!(at: at)
    rescue PublishableTranslation::EnglishMustBePublished
      next
    end
  end
end
```

Only the expected English-first domain error is skipped. Let database and programming errors escape so Solid Queue records and retries the job; rows published before a retry remain unchanged because `publish!` is idempotent.

- [ ] **Step 4: Run the job tests**

Run:

```bash
bin/rails test test/jobs/publish_due_translations_job_test.rb
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
bin/rails test test/config/recurring_schedule_test.rb
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
bin/rails test test/jobs/publish_due_translations_job_test.rb test/config/recurring_schedule_test.rb
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
- Test: `test/controllers/admin/dashboard_controller_test.rb`

**Interfaces:**

- Consumes: Task 1 `draft`, `upcoming`, `due`, `publishable_now?`, and `publication_parent` behavior.
- Produces: Dashboard collections `@draft_translations`, `@upcoming_translations`, and `@failed_publications`, each capped at ten records.

- [ ] **Step 1: Write a failing dashboard request test**

Create `test/controllers/admin/dashboard_controller_test.rb`:

```ruby
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows drafts upcoming schedules and overdue English-blocked work" do
    sign_in_as_admin
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
    published_post.translations.first.publish!(at: now - 1.day)

    get admin_root_path

    assert_response :success
    assert_select "#draft-content", text: /Draft English/
    assert_select "#upcoming-publications", text: /Upcoming Vietnamese/
    assert_select "#failed-publications", text: /Blocked French/
    assert_no_match(/Published Post/, response.body)
  end
end
```

- [ ] **Step 2: Run the dashboard test and verify the summaries are absent**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb
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
      .reject(&:publishable_now?)
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
            <time datetime="<%= translation.scheduled_at.iso8601 %>"><%= l translation.scheduled_at, format: :long %></time>
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
bin/rails test test/controllers/admin/dashboard_controller_test.rb test/controllers/admin/translation_publications_controller_test.rb test/models/publishable_translation_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit actionable dashboard summaries**

```bash
git add app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb test/controllers/admin/dashboard_controller_test.rb
git commit -m "feat: show publishing work on admin dashboard"
```

---

### Task 5: Prove the Owner Workflow and Public Isolation

**Files:**

- Create: `test/system/admin_publishing_test.rb`

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
    admin = AdminUser.create!(
      email: "owner@example.test",
      password: "correct horse battery staple",
      password_confirmation: "correct horse battery staple",
      totp_secret: ROTP::Base32.random
    )
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

    visit new_admin_session_path
    fill_in "Email", with: admin.email
    fill_in "Password", with: "correct horse battery staple"
    click_on "Continue"
    assert_current_path admin_totp_challenge_path
    fill_in "Authentication code", with: ROTP::TOTP.new(admin.totp_secret).now
    click_on "Verify"

    visit edit_admin_project_path(project)
    within "##{dom_id(french, :publication)}" do
      assert_button "Publish", disabled: true
      assert_text "Publish the English translation before publishing this locale."
    end

    within "##{dom_id(english, :publication)}" do
      click_on "Publish"
    end
    assert_text "English Case Study was published"

    within "##{dom_id(french, :publication)}" do
      click_on "Publish"
    end
    assert_text "Étude de cas was published"

    visit "/fr/projects/#{french.slug}"
    assert_text "Étude de cas"
    visit "/vi/projects/#{vietnamese.slug}"
    assert_no_text "Dự án"

    scheduled_time = 1.hour.from_now.change(sec: 0)
    visit edit_admin_project_path(project)
    within "##{dom_id(vietnamese, :publication)}" do
      fill_in "Schedule vi publication", with: scheduled_time.strftime("%Y-%m-%dT%H:%M")
      click_on "Schedule"
    end
    assert_text "Dự án was scheduled"

    travel_to scheduled_time + 1.minute do
      PublishDueTranslationsJob.perform_now
    end

    visit "/vi/projects/#{vietnamese.slug}"
    assert_text "Dự án"
    assert_text "Nội dung"
  end
end
```

- [ ] **Step 2: Run the end-to-end system test**

Run:

```bash
bin/rails test test/system/admin_publishing_test.rb
```

Expected: PASS. The test must use the accepted Phase 3 password-and-TOTP UI; do not add a test-only authentication route or bypass the second factor.

- [ ] **Step 3: Run the focused system and public request suites**

Run:

```bash
bin/rails test test/system/admin_publishing_test.rb test/controllers/public/projects_controller_test.rb test/controllers/public/posts_controller_test.rb
```

Expected: PASS. The Vietnamese detail URL must be 404 before the due job and 200 afterward; French publication must not expose Vietnamese.

- [ ] **Step 4: Commit the acceptance workflow**

```bash
git add test/system/admin_publishing_test.rb
git commit -m "test: cover localized publishing workflow"
```

---

## Phase Verification and Acceptance

- [ ] **Run every Phase 5 focused test together**

```bash
bin/rails test test/models/publishable_translation_test.rb test/controllers/admin/translation_publications_controller_test.rb test/jobs/publish_due_translations_job_test.rb test/config/recurring_schedule_test.rb test/controllers/admin/dashboard_controller_test.rb test/system/admin_publishing_test.rb
```

Expected: PASS with zero failures and zero errors.

- [ ] **Run the complete application suites required at the phase boundary**

```bash
bin/rails test
bin/rails test:system
```

Expected: both commands PASS.

- [ ] **Verify recurrence is loadable by Solid Queue**

```bash
RAILS_ENV=production bin/rails runner 'task = YAML.safe_load_file(Rails.root.join("config/recurring.yml")).fetch("production").fetch("publish_due_translations"); abort unless task == {"class" => "PublishDueTranslationsJob", "schedule" => "every minute"}; puts task'
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
5. Schedule Vietnamese one minute ahead; verify it remains unavailable before the scan and becomes public after the recurring job runs.
6. Unpublish French; verify its slug is unchanged and its public URL returns 404.
7. Open `/admin`; verify draft, upcoming, and blocked-overdue records appear under the correct actionable headings.

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
