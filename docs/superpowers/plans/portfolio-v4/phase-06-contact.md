# Phase 6: Contact Delivery and Admin Inbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let visitors persist localized contact messages before asynchronous owner notification, while giving the owner a mobile-first inbox with safe, idempotent delivery retries.

**Architecture:** `ContactMessage` is the source of truth for inbox and delivery state. A create-commit callback and a failed-to-pending update-commit callback enqueue one ID-only `ContactNotificationJob`; the job serializes concurrent attempts with a row lock, skips delivered records, and stores only a safe exception-class summary on failure. The public controller uses Rails 8.1's native rate limiter plus a non-persisted honeypot, and the authenticated admin controller exposes explicit state transitions and retry actions.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Action Mailer, Active Job with Solid Queue, SQLite, Hotwire, Tailwind CSS, Minitest, Capybara

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
- Never put a contact message body in a job argument, exception summary, flash, or application log. Only the database row and generated email contain it.
- The public success response means “saved,” not “email delivered.”

## Dependencies and Preserved Interfaces

This phase starts after Phases 1–5 pass. It consumes these established interfaces without renaming them:

- `Profile.current.public_contact_email` supplies the owner notification address.
- `Current.admin_user` and `Admin::BaseController#require_admin!` protect `/admin`.
- Public controllers inherit locale setup from `PublicController`; `localized_contact_path(locale:)` remains the GET helper for `/:locale/contact`.
- The existing public and admin layouts, shared form error styles, semantic color tokens, and mobile container classes remain in use.
- Authentication tests use the Phase 3 helpers `sign_in_as_admin` for request tests and `sign_in_owner` for system tests.

This phase produces the parent-plan interfaces exactly:

- `ContactMessage#mark_delivered!`
- `ContactMessage#mark_failed!(error)`
- `ContactNotificationJob.perform(contact_message_id)`
- `ContactMailer.owner_notification(contact_message)`
- Admin message state and retry routes

It additionally defines `ContactMessage#mark_read!`, `#mark_unread!`, `#archive!`, and `#retry_delivery!` so controllers do not duplicate transition logic.

## File Map

| Path                                                    | Responsibility                                                                      |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `db/migrate/20260902060000_create_contact_messages.rb`  | Durable inbox and delivery columns, indexes, and database state constraints         |
| `app/models/contact_message.rb`                         | Validation, inbox transitions, delivery transitions, and after-commit enqueue rules |
| `app/jobs/contact_notification_job.rb`                  | ID-only, idempotent mail delivery and failure persistence                           |
| `app/mailers/contact_mailer.rb`                         | Owner notification envelope                                                         |
| `app/views/contact_mailer/owner_notification.html.erb`  | HTML notification body                                                              |
| `app/views/contact_mailer/owner_notification.text.erb`  | Plain-text notification body                                                        |
| `app/controllers/public/contact_messages_controller.rb` | Localized create flow, honeypot, and native rate limiting                           |
| `app/views/public/contact_messages/new.html.erb`        | Accessible localized public form and feedback                                       |
| `app/controllers/admin/messages_controller.rb`          | Authenticated inbox, state actions, and retry action                                |
| `app/views/admin/messages/index.html.erb`               | Mobile-first message cards                                                          |
| `app/views/admin/messages/show.html.erb`                | Message detail and actions                                                          |
| `config/routes.rb`                                      | Public POST and admin inbox member routes                                           |
| `config/initializers/filter_parameter_logging.rb`       | Filters every `body` request parameter                                              |
| `config/locales/{en,fr,vi}.yml`                         | Contact form, validation, and receipt copy                                          |
| `config/environments/test.rb`                           | In-process cache needed to exercise native throttling                               |
| `test/models/contact_message_test.rb`                   | Schema validation and state transition coverage                                     |
| `test/jobs/contact_notification_job_test.rb`            | Success, failure, missing-row, and duplicate-attempt coverage                       |
| `test/mailers/contact_mailer_test.rb`                   | Recipient, reply-to, subject, and multipart body coverage                           |
| `test/requests/public/contact_messages_test.rb`         | Persistence, validation, honeypot, throttling, localization, and filtering          |
| `test/requests/admin/messages_test.rb`                  | Authorization, state actions, and idempotent retry coverage                         |
| `test/system/contact_flow_test.rb`                      | Visitor receipt and owner inbox workflow                                            |

---

### Task 1: Persist Messages and Centralize State Transitions

**Files:**

- Create: `db/migrate/20260902060000_create_contact_messages.rb`
- Create: `app/models/contact_message.rb`
- Create: `test/models/contact_message_test.rb`

**Interfaces:**

- Consumes: Active Record and SQLite from Phase 1.
- Produces: `ContactMessage` with `state` values `unread`, `read`, `archived`; `email_delivery_state` values `pending`, `delivered`, `failed`; `mark_read!`, `mark_unread!`, `archive!`, `mark_delivered!`, and `mark_failed!(error)`.

- [ ] **Step 1: Write the model tests first**

```ruby
# test/models/contact_message_test.rb
require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  def valid_message
    ContactMessage.new(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Could we discuss a Rails project?"
    )
  end

  test "defaults to unread and pending" do
    message = valid_message
    message.save!

    assert message.unread?
    assert message.pending?
    assert_nil message.delivered_at
    assert_nil message.last_delivery_error
  end

  test "requires bounded sender fields and a valid email" do
    message = ContactMessage.new

    assert_not message.valid?
    assert_includes message.errors[:sender_name], "can't be blank"
    assert_includes message.errors[:sender_email], "can't be blank"
    assert_includes message.errors[:subject], "can't be blank"
    assert_includes message.errors[:body], "can't be blank"

    message.assign_attributes(
      sender_name: "A" * 121,
      sender_email: "not-an-email",
      subject: "S" * 201,
      body: "B" * 10_001
    )
    assert_not message.valid?
  end

  test "moves through explicit inbox states" do
    message = valid_message.tap(&:save!)

    message.mark_read!
    assert message.read?
    message.mark_unread!
    assert message.unread?
    message.archive!
    assert message.archived?
  end

  test "marks delivery successful and clears an old safe error" do
    message = valid_message.tap(&:save!)
    message.update!(email_delivery_state: :failed, last_delivery_error: "TimeoutError: delivery failed")

    travel_to Time.zone.parse("2026-09-02 12:00:00") do
      message.mark_delivered!
      assert message.delivered?
      assert_equal Time.current, message.delivered_at
      assert_nil message.last_delivery_error
    end
  end

  test "marks delivery failed without persisting exception text" do
    message = valid_message.tap(&:save!)
    secret_body = "private-message-body"

    message.mark_failed!(RuntimeError.new("SMTP echoed #{secret_body}"))

    assert message.failed?
    assert_nil message.delivered_at
    assert_equal "RuntimeError: delivery failed", message.last_delivery_error
    assert_not_includes message.last_delivery_error, secret_body
  end
end
```

- [ ] **Step 2: Run the test to verify the missing model failure**

Run: `bin/rails test test/models/contact_message_test.rb`

Expected: FAIL with `uninitialized constant ContactMessage`.

- [ ] **Step 3: Create the migration and model**

```ruby
# db/migrate/20260902060000_create_contact_messages.rb
class CreateContactMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_messages do |t|
      t.string :sender_name, null: false
      t.string :sender_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.integer :state, null: false, default: 0
      t.integer :email_delivery_state, null: false, default: 0
      t.datetime :delivered_at
      t.string :last_delivery_error
      t.timestamps

      t.check_constraint "state IN (0, 1, 2)", name: "contact_messages_state_check"
      t.check_constraint "email_delivery_state IN (0, 1, 2)", name: "contact_messages_delivery_state_check"
    end

    add_index :contact_messages, [:state, :created_at]
    add_index :contact_messages, [:email_delivery_state, :created_at], name: "index_contact_messages_on_delivery_state_and_created_at"
  end
end
```

```ruby
# app/models/contact_message.rb
class ContactMessage < ApplicationRecord
  enum :state, { unread: 0, read: 1, archived: 2 }, default: :unread, validate: true
  enum :email_delivery_state, { pending: 0, delivered: 1, failed: 2 }, default: :pending, validate: true

  validates :sender_name, presence: true, length: { maximum: 120 }
  validates :sender_email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :last_delivery_error, length: { maximum: 255 }, allow_nil: true

  def mark_read!
    update!(state: :read)
  end

  def mark_unread!
    update!(state: :unread)
  end

  def archive!
    update!(state: :archived)
  end

  def mark_delivered!
    update!(
      email_delivery_state: :delivered,
      delivered_at: Time.current,
      last_delivery_error: nil
    )
  end

  def mark_failed!(error)
    error_class = error.class.name.to_s.gsub(/[^A-Za-z0-9_:]/, "").presence || "DeliveryError"
    update!(
      email_delivery_state: :failed,
      delivered_at: nil,
      last_delivery_error: "#{error_class}: delivery failed".truncate(255)
    )
  end
end
```

Run: `bin/rails db:migrate`

Expected: migration creates `contact_messages` and both check constraints.

- [ ] **Step 4: Run the focused tests**

Run: `bin/rails test test/models/contact_message_test.rb`

Expected: 5 tests pass.

- [ ] **Step 5: Commit the persistence boundary**

```bash
git add db/migrate/20260902060000_create_contact_messages.rb db/schema.rb app/models/contact_message.rb test/models/contact_message_test.rb
git commit -m "feat: persist contact message states"
```

---

### Task 2: Enqueue After Commit and Persist Mail Delivery Results

**Files:**

- Modify: `app/models/contact_message.rb`
- Modify: `test/models/contact_message_test.rb`
- Create: `app/jobs/contact_notification_job.rb`
- Create: `app/mailers/contact_mailer.rb`
- Create: `app/views/contact_mailer/owner_notification.html.erb`
- Create: `app/views/contact_mailer/owner_notification.text.erb`
- Create: `test/jobs/contact_notification_job_test.rb`
- Create: `test/mailers/contact_mailer_test.rb`

**Interfaces:**

- Consumes: `Profile.current.public_contact_email` and Active Job's configured Solid Queue adapter.
- Produces: `ContactNotificationJob.perform(contact_message_id)`, `ContactMailer.owner_notification(contact_message)`, commit-only initial enqueue, commit-only failed-to-pending retry enqueue, and `ContactMessage#retry_delivery! -> Boolean`.

- [ ] **Step 1: Add failing enqueue and retry tests to the model test**

```ruby
# Add inside ContactMessageTest.
include ActiveJob::TestHelper

setup do
  clear_enqueued_jobs
end

test "enqueues only after a new message commits" do
  message = valid_message

  assert_enqueued_with(job: ContactNotificationJob) do
    message.save!
  end
  assert_equal [message.id], enqueued_jobs.last.fetch(:args)
end

test "retry transitions failed to pending once and enqueues after commit" do
  message = valid_message.tap(&:save!)
  clear_enqueued_jobs
  message.update!(email_delivery_state: :failed, last_delivery_error: "TimeoutError: delivery failed")

  assert_enqueued_with(job: ContactNotificationJob, args: [message.id]) do
    assert message.retry_delivery!
  end
  assert message.pending?
  assert_nil message.last_delivery_error

  assert_no_enqueued_jobs do
    assert_equal false, message.retry_delivery!
  end
end

test "delivered messages cannot be requeued" do
  message = valid_message.tap(&:save!)
  clear_enqueued_jobs
  message.mark_delivered!

  assert_no_enqueued_jobs do
    assert_equal false, message.retry_delivery!
  end
end
```

- [ ] **Step 2: Add failing job and mailer tests**

```ruby
# test/jobs/contact_notification_job_test.rb
require "test_helper"

class ContactNotificationJobTest < ActiveJob::TestCase
  def create_message
    ContactMessage.create!(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Private project details"
    )
  end

  test "delivers once and records success" do
    message = create_message
    delivery = Minitest::Mock.new
    delivery.expect(:deliver_now, true)

    ContactMailer.stub(:owner_notification, delivery) do
      ContactNotificationJob.perform_now(message.id)
      ContactNotificationJob.perform_now(message.id)
    end

    delivery.verify
    assert message.reload.delivered?
    assert_not_nil message.delivered_at
  end

  test "persists a safe failure and does not raise" do
    message = create_message
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) do
      raise RuntimeError, "SMTP included Private project details"
    end

    ContactMailer.stub(:owner_notification, delivery) do
      ContactNotificationJob.perform_now(message.id)
    end

    assert message.reload.failed?
    assert_equal "RuntimeError: delivery failed", message.last_delivery_error
    assert_not_includes message.last_delivery_error, message.body
  end

  test "missing messages are a no-op" do
    assert_nothing_raised do
      ContactNotificationJob.perform_now(-1)
    end
  end

  test "serialized arguments contain only the database id" do
    message = create_message
    serialized = ContactNotificationJob.new(message.id).serialize

    assert_equal [message.id], serialized.fetch("arguments")
    assert_not_includes serialized.to_json, message.body
  end
end
```

```ruby
# test/mailers/contact_mailer_test.rb
require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "builds a multipart owner notification" do
    profile = Profile.current
    profile.update!(public_contact_email: "owner@example.test")
    message = ContactMessage.create!(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Could we work together?"
    )

    email = ContactMailer.owner_notification(message)

    assert_equal ["owner@example.test"], email.to
    assert_equal ["portfolio@example.test"], email.from
    assert_equal ["ada@example.test"], email.reply_to
    assert_equal "[Portfolio contact] Project enquiry", email.subject
    assert_includes email.text_part.body.decoded, "Could we work together?"
    assert_includes email.html_part.body.decoded, "Could we work together?"
  end
end
```

- [ ] **Step 3: Run tests to verify the delivery interfaces are missing**

Run: `bin/rails test test/models/contact_message_test.rb test/jobs/contact_notification_job_test.rb test/mailers/contact_mailer_test.rb`

Expected: FAIL because `ContactNotificationJob`, `ContactMailer`, and `retry_delivery!` do not exist.

- [ ] **Step 4: Add commit callbacks and the atomic retry transition**

Add these lines immediately after the enums in `app/models/contact_message.rb`:

```ruby
after_create_commit :enqueue_owner_notification
after_update_commit :enqueue_owner_notification, if: :delivery_requeued?
```

Add these methods before the existing `mark_delivered!` method:

```ruby
def retry_delivery!
  with_lock do
    return false unless failed?

    update!(email_delivery_state: :pending, last_delivery_error: nil)
    true
  end
end
```

Add this private section at the end of the class:

```ruby
private

  def delivery_requeued?
    saved_change_to_email_delivery_state? && pending?
  end

  def enqueue_owner_notification
    ContactNotificationJob.perform_later(id)
  end
```

The callbacks intentionally enqueue after database commit. The retry method changes only `failed` to `pending`, so repeated clicks and concurrent requests produce one state transition and one committed enqueue.

- [ ] **Step 5: Implement the job and mailer**

```ruby
# app/jobs/contact_notification_job.rb
class ContactNotificationJob < ApplicationJob
  queue_as :default

  def perform(contact_message_id)
    contact_message = ContactMessage.find(contact_message_id)

    contact_message.with_lock do
      return if contact_message.delivered?

      ContactMailer.owner_notification(contact_message).deliver_now
      contact_message.mark_delivered!
    end
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    contact_message&.mark_failed!(error) unless contact_message&.delivered?
  end
end
```

```ruby
# app/mailers/contact_mailer.rb
class ContactMailer < ApplicationMailer
  def owner_notification(contact_message)
    @contact_message = contact_message

    mail(
      to: Profile.current.public_contact_email,
      from: ENV.fetch("MAILER_FROM", "portfolio@example.test"),
      reply_to: contact_message.sender_email,
      subject: "[Portfolio contact] #{contact_message.subject}"
    )
  end
end
```

```erb
<%# app/views/contact_mailer/owner_notification.text.erb %>
New portfolio contact message

From: <%= @contact_message.sender_name %> <<%= @contact_message.sender_email %>>
Subject: <%= @contact_message.subject %>

<%= @contact_message.body %>
```

```erb
<%# app/views/contact_mailer/owner_notification.html.erb %>
<h1>New portfolio contact message</h1>
<p><strong>From:</strong> <%= @contact_message.sender_name %> &lt;<%= @contact_message.sender_email %>&gt;</p>
<p><strong>Subject:</strong> <%= @contact_message.subject %></p>
<hr>
<p><%= simple_format(@contact_message.body) %></p>
```

The row lock is the minimum mechanism that prevents two queued attempts from sending an already-delivered row concurrently. SMTP cannot provide exactly-once delivery if the process dies after the provider accepts mail but before SQLite records success; a provider idempotency key can be added only if the selected SMTP provider later supports one.

- [ ] **Step 6: Run focused delivery tests**

Run: `bin/rails test test/models/contact_message_test.rb test/jobs/contact_notification_job_test.rb test/mailers/contact_mailer_test.rb`

Expected: all model, job, and mailer tests pass; the duplicate job test calls `deliver_now` once.

- [ ] **Step 7: Commit asynchronous delivery**

```bash
git add app/models/contact_message.rb app/jobs/contact_notification_job.rb app/mailers/contact_mailer.rb app/views/contact_mailer test/models/contact_message_test.rb test/jobs/contact_notification_job_test.rb test/mailers/contact_mailer_test.rb
git commit -m "feat: deliver contact notifications after commit"
```

---

### Task 3: Build the Localized, Abuse-Resistant Public Form

**Files:**

- Modify: `config/routes.rb`
- Modify: `config/environments/test.rb`
- Modify: `config/initializers/filter_parameter_logging.rb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/fr.yml`
- Modify: `config/locales/vi.yml`
- Create: `app/controllers/public/contact_messages_controller.rb`
- Create: `app/views/public/contact_messages/new.html.erb`
- Create: `test/requests/public/contact_messages_test.rb`

**Interfaces:**

- Consumes: locale setup from `PublicController`, `localized_contact_path(locale:)`, shared public layout, and `ContactMessage` create-commit enqueue.
- Produces: `GET /:locale/contact`, `POST /:locale/contact`, a hidden `contact_message[website]` honeypot contract, five requests per IP per ten minutes, localized errors, and persisted-receipt feedback.

- [ ] **Step 1: Write failing public request tests**

```ruby
# test/requests/public/contact_messages_test.rb
require "test_helper"

class Public::ContactMessagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
  end

  teardown do
    Rails.cache.clear
  end

  def valid_params
    {
      contact_message: {
        sender_name: "Ada Lovelace",
        sender_email: "ada@example.test",
        subject: "Project enquiry",
        body: "Please contact me about a project.",
        website: ""
      }
    }
  end

  test "renders localized forms" do
    get localized_contact_path(locale: :en)
    assert_response :success
    assert_select "h1", "Contact"

    get localized_contact_path(locale: :fr)
    assert_response :success
    assert_select "h1", "Contactez-moi"

    get localized_contact_path(locale: :vi)
    assert_response :success
    assert_select "h1", "Liên hệ"
  end

  test "renders localized validation messages" do
    params = valid_params
    params[:contact_message][:sender_email] = "invalid"

    post localized_contact_path(locale: :fr), params: params

    assert_response :unprocessable_entity
    assert_includes response.body, "n’est pas valide"
  end

  test "persists before returning receipt feedback and enqueues one id-only job" do
    assert_difference("ContactMessage.count", 1) do
      assert_enqueued_with(job: ContactNotificationJob) do
        post localized_contact_path(locale: :en), params: valid_params
      end
    end

    message = ContactMessage.order(:id).last
    assert_redirected_to localized_contact_path(locale: :en)
    follow_redirect!
    assert_includes response.body, "Your message has been saved."
    assert message.pending?
    assert_equal [message.id], enqueued_jobs.last.fetch(:args)
  end

  test "invalid input renders field errors without persistence or mail" do
    params = valid_params
    params[:contact_message][:sender_email] = "invalid"

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: params
      end
    end

    assert_response :unprocessable_entity
    assert_select "input[value='Ada Lovelace']"
    assert_includes response.body, "is invalid"
  end

  test "a filled honeypot is rejected without persistence or mail" do
    params = valid_params
    params[:contact_message][:website] = "https://spam.example"

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: params
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "We could not accept that submission."
  end

  test "the sixth request from one IP is rate limited" do
    5.times do
      post localized_contact_path(locale: :en), params: valid_params, headers: { "REMOTE_ADDR" => "192.0.2.10" }
      assert_response :redirect
    end

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: valid_params, headers: { "REMOTE_ADDR" => "192.0.2.10" }
      end
    end

    assert_response :too_many_requests
    assert_includes response.body, "Too many messages were submitted. Please try again later."
  end

  test "message body parameters are filtered from logs" do
    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(body: "private-message-body")

    assert_equal "[FILTERED]", filtered.fetch(:body)
  end
end
```

- [ ] **Step 2: Run the public request test to verify route/controller failures**

Run: `bin/rails test test/requests/public/contact_messages_test.rb`

Expected: FAIL because the POST route and `Public::ContactMessagesController` are absent.

- [ ] **Step 3: Replace the existing localized contact shell route and add admin-independent POST routing**

Within the existing locale scope in `config/routes.rb`, replace its current contact-page route with these two routes:

```ruby
get "contact", to: "public/contact_messages#new", as: :localized_contact
post "contact", to: "public/contact_messages#create"
```

Do not add an unprefixed public route. `localized_contact_path(locale:)` remains unchanged for links and form submission.

- [ ] **Step 4: Implement native throttling, honeypot rejection, and persistence**

```ruby
# app/controllers/public/contact_messages_controller.rb
module Public
  class ContactMessagesController < PublicController
    rate_limit to: 5,
      within: 10.minutes,
      only: :create,
      by: -> { request.remote_ip },
      with: -> { render_rate_limited }

    def new
      @contact_message = ContactMessage.new
    end

    def create
      @contact_message = ContactMessage.new(contact_message_params)

      if honeypot_filled?
        flash.now[:alert] = t("contact.spam_rejected")
        render :new, status: :unprocessable_entity
      elsif @contact_message.save
        redirect_to localized_contact_path(locale: I18n.locale), notice: t("contact.received")
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

      def contact_message_params
        params.require(:contact_message).permit(:sender_name, :sender_email, :subject, :body)
      end

      def honeypot_filled?
        params.dig(:contact_message, :website).present?
      end

      def render_rate_limited
        @contact_message = ContactMessage.new(contact_message_params)
        flash.now[:alert] = t("contact.rate_limited")
        render :new, status: :too_many_requests
      end
  end
end
```

The honeypot is checked before save, and `website` is never permitted or persisted. The rate limit uses the existing Rails cache rather than a dependency. Add this line inside `Rails.application.configure` in `config/environments/test.rb` so the request test exercises counters:

```ruby
config.cache_store = :memory_store
```

- [ ] **Step 5: Filter the body parameter and add the localized view**

Ensure `config/initializers/filter_parameter_logging.rb` includes `:body` in the generated filter list:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :body
]
```

```erb
<%# app/views/public/contact_messages/new.html.erb %>
<main class="mx-auto w-full max-w-3xl px-4 py-12 sm:px-6" aria-labelledby="contact-title">
  <p class="text-sm font-semibold uppercase tracking-widest text-accent"><%= t("navigation.contact") %></p>
  <h1 id="contact-title" class="mt-3 text-4xl font-bold sm:text-6xl"><%= t("contact.title") %></h1>
  <p class="mt-4 max-w-prose"><%= t("contact.intro") %></p>

  <%= form_with model: @contact_message, url: localized_contact_path(locale: I18n.locale), class: "mt-8 space-y-6" do |form| %>
    <% if @contact_message.errors.any? %>
      <div role="alert" class="border border-red-600 p-4">
        <p class="font-semibold"><%= t("contact.errors", count: @contact_message.errors.count) %></p>
        <ul class="mt-2 list-disc pl-5">
          <% @contact_message.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div class="absolute -left-[10000px] top-auto h-px w-px overflow-hidden" aria-hidden="true">
      <%= label_tag "contact_message_website", t("contact.fields.website") %>
      <%= text_field_tag "contact_message[website]", nil, id: "contact_message_website", tabindex: -1, autocomplete: "off" %>
    </div>

    <% { sender_name: "text", sender_email: "email", subject: "text" }.each do |field, type| %>
      <div>
        <%= form.label field, t("contact.fields.#{field}"), class: "block font-semibold" %>
        <%= form.public_send("#{type}_field", field, required: true, class: "mt-2 min-h-12 w-full border bg-transparent px-3 py-2") %>
      </div>
    <% end %>

    <div>
      <%= form.label :body, t("contact.fields.body"), class: "block font-semibold" %>
      <%= form.text_area :body, required: true, rows: 8, maxlength: 10_000, class: "mt-2 w-full border bg-transparent px-3 py-2" %>
    </div>

    <%= form.submit t("contact.submit"), class: "min-h-12 cursor-pointer bg-accent px-6 py-3 font-semibold text-accent-foreground" %>
  <% end %>
</main>
```

- [ ] **Step 6: Add exact English, French, and Vietnamese copy**

Merge these trees beneath each existing locale root; retain all existing navigation and interface keys.

```yaml
# config/locales/en.yml
en:
  contact:
    title: "Contact"
    intro: "Tell me about your project or question."
    fields:
      sender_name: "Name"
      sender_email: "Email"
      subject: "Subject"
      body: "Message"
      website: "Website"
    submit: "Send message"
    errors:
      one: "Please correct 1 error."
      other: "Please correct %{count} errors."
    received: "Your message has been saved."
    spam_rejected: "We could not accept that submission."
    rate_limited: "Too many messages were submitted. Please try again later."
  activerecord:
    attributes:
      contact_message:
        sender_name: "Name"
        sender_email: "Email"
        subject: "Subject"
        body: "Message"
  errors:
    messages:
      blank: "can't be blank"
      invalid: "is invalid"
      too_long: "is too long (maximum is %{count} characters)"
```

```yaml
# config/locales/fr.yml
fr:
  contact:
    title: "Contactez-moi"
    intro: "Parlez-moi de votre projet ou de votre question."
    fields:
      sender_name: "Nom"
      sender_email: "Adresse e-mail"
      subject: "Objet"
      body: "Message"
      website: "Site web"
    submit: "Envoyer le message"
    errors:
      one: "Veuillez corriger 1 erreur."
      other: "Veuillez corriger %{count} erreurs."
    received: "Votre message a été enregistré."
    spam_rejected: "Nous n’avons pas pu accepter cet envoi."
    rate_limited: "Trop de messages ont été envoyés. Veuillez réessayer plus tard."
  activerecord:
    attributes:
      contact_message:
        sender_name: "Nom"
        sender_email: "Adresse e-mail"
        subject: "Objet"
        body: "Message"
  errors:
    messages:
      blank: "ne peut pas être vide"
      invalid: "n’est pas valide"
      too_long: "est trop long (maximum : %{count} caractères)"
```

```yaml
# config/locales/vi.yml
vi:
  contact:
    title: "Liên hệ"
    intro: "Hãy chia sẻ về dự án hoặc câu hỏi của bạn."
    fields:
      sender_name: "Tên"
      sender_email: "Email"
      subject: "Chủ đề"
      body: "Tin nhắn"
      website: "Trang web"
    submit: "Gửi tin nhắn"
    errors:
      one: "Vui lòng sửa 1 lỗi."
      other: "Vui lòng sửa %{count} lỗi."
    received: "Tin nhắn của bạn đã được lưu."
    spam_rejected: "Chúng tôi không thể chấp nhận nội dung gửi này."
    rate_limited: "Đã gửi quá nhiều tin nhắn. Vui lòng thử lại sau."
  activerecord:
    attributes:
      contact_message:
        sender_name: "Tên"
        sender_email: "Email"
        subject: "Chủ đề"
        body: "Tin nhắn"
  errors:
    messages:
      blank: "không được để trống"
      invalid: "không hợp lệ"
      too_long: "quá dài (tối đa %{count} ký tự)"
```

- [ ] **Step 7: Run focused public tests**

Run: `bin/rails test test/requests/public/contact_messages_test.rb test/models/contact_message_test.rb test/jobs/contact_notification_job_test.rb`

Expected: all tests pass; invalid, honeypot, and sixth requests create no rows and enqueue no jobs.

- [ ] **Step 8: Commit the public flow**

```bash
git add config/routes.rb config/environments/test.rb config/initializers/filter_parameter_logging.rb config/locales/en.yml config/locales/fr.yml config/locales/vi.yml app/controllers/public/contact_messages_controller.rb app/views/public/contact_messages/new.html.erb test/requests/public/contact_messages_test.rb
git commit -m "feat: add localized contact form protections"
```

---

### Task 4: Add the Mobile Admin Inbox and Idempotent Retry

**Files:**

- Modify: `config/routes.rb`
- Create: `app/controllers/admin/messages_controller.rb`
- Create: `app/views/admin/messages/index.html.erb`
- Create: `app/views/admin/messages/show.html.erb`
- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Create: `test/requests/admin/messages_test.rb`

**Interfaces:**

- Consumes: `Admin::BaseController#require_admin!`, `ContactMessage` transition methods, and commit-only `retry_delivery!` enqueue.
- Produces: `admin_messages_path`, `admin_message_path(message)`, `mark_read_admin_message_path(message)`, `mark_unread_admin_message_path(message)`, `archive_admin_message_path(message)`, and `retry_email_admin_message_path(message)`.

- [ ] **Step 1: Write failing authorization, state, and retry request tests**

```ruby
# test/requests/admin/messages_test.rb
require "test_helper"

class Admin::MessagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @message = ContactMessage.create!(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Original private body"
    )
    clear_enqueued_jobs
  end

  test "requires an authenticated owner" do
    get admin_messages_path
    assert_response :redirect
  end

  test "lists and shows message state on a mobile card" do
    sign_in_as_admin

    get admin_messages_path
    assert_response :success
    assert_select "article[data-message-id='#{@message.id}']"
    assert_includes response.body, "Project enquiry"

    get admin_message_path(@message)
    assert_response :success
    assert_includes response.body, "Original private body"
  end

  test "marks read unread and archived through explicit routes" do
    sign_in_as_admin

    patch mark_read_admin_message_path(@message)
    assert @message.reload.read?

    patch mark_unread_admin_message_path(@message)
    assert @message.reload.unread?

    patch archive_admin_message_path(@message)
    assert @message.reload.archived?
  end

  test "failed delivery retry is idempotent and preserves the message" do
    sign_in_as_admin
    @message.mark_failed!(RuntimeError.new("provider unavailable"))
    original = @message.attributes.slice("sender_name", "sender_email", "subject", "body", "created_at")

    assert_enqueued_with(job: ContactNotificationJob, args: [@message.id]) do
      post retry_email_admin_message_path(@message)
    end
    assert @message.reload.pending?
    assert_equal original, @message.attributes.slice("sender_name", "sender_email", "subject", "body", "created_at")

    assert_no_enqueued_jobs do
      post retry_email_admin_message_path(@message)
    end
  end
end
```

- [ ] **Step 2: Run the admin request test to verify routes are missing**

Run: `bin/rails test test/requests/admin/messages_test.rb`

Expected: FAIL with an undefined `admin_messages_path`.

- [ ] **Step 3: Add protected inbox routes**

Inside the existing `namespace :admin` block in `config/routes.rb`, add:

```ruby
resources :messages, only: [:index, :show] do
  member do
    patch :mark_read
    patch :mark_unread
    patch :archive
    post :retry_email
  end
end
```

All actions inherit the existing admin authentication boundary and CSRF protection. There is no public JSON endpoint and no delete action.

- [ ] **Step 4: Implement the inbox controller**

```ruby
# app/controllers/admin/messages_controller.rb
module Admin
  class MessagesController < BaseController
    before_action :set_message, except: :index

    def index
      scope = params[:state] == "archived" ? ContactMessage.archived : ContactMessage.where.not(state: :archived)
      @messages = scope.order(created_at: :desc)
    end

    def show
    end

    def mark_read
      @message.mark_read!
      redirect_back fallback_location: admin_message_path(@message), notice: "Message marked as read."
    end

    def mark_unread
      @message.mark_unread!
      redirect_back fallback_location: admin_message_path(@message), notice: "Message marked as unread."
    end

    def archive
      @message.archive!
      redirect_to admin_messages_path, notice: "Message archived."
    end

    def retry_email
      if @message.retry_delivery!
        redirect_back fallback_location: admin_message_path(@message), notice: "Email retry queued."
      else
        redirect_back fallback_location: admin_message_path(@message), alert: "Email is already delivered or queued."
      end
    end

    private

      def set_message
        @message = ContactMessage.find(params[:id])
      end
  end
end
```

- [ ] **Step 5: Build card-based index and detail views**

```erb
<%# app/views/admin/messages/index.html.erb %>
<header class="flex flex-wrap items-end justify-between gap-4">
  <div>
    <p class="text-sm font-semibold uppercase tracking-widest">Inbox</p>
    <h1 class="text-3xl font-bold">Contact messages</h1>
  </div>
  <nav class="flex min-h-11 items-center gap-4" aria-label="Message filters">
    <%= link_to "Inbox", admin_messages_path, class: "underline" %>
    <%= link_to "Archived", admin_messages_path(state: :archived), class: "underline" %>
  </nav>
</header>

<div class="mt-8 grid gap-4">
  <% @messages.each do |message| %>
    <article data-message-id="<%= message.id %>" class="border p-4 sm:p-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="break-words font-semibold"><%= message.sender_name %></p>
          <h2 class="break-words text-xl"><%= link_to message.subject, admin_message_path(message), class: "underline" %></h2>
        </div>
        <div class="flex flex-wrap gap-2 text-xs uppercase">
          <span><%= message.state %></span>
          <span><%= message.email_delivery_state %></span>
        </div>
      </div>
      <p class="mt-3 text-sm"><%= l(message.created_at, format: :long) %></p>
      <div class="mt-4 flex flex-wrap gap-3">
        <% if message.unread? %>
          <%= button_to "Mark read", mark_read_admin_message_path(message), method: :patch, class: "min-h-11 border px-4" %>
        <% else %>
          <%= button_to "Mark unread", mark_unread_admin_message_path(message), method: :patch, class: "min-h-11 border px-4" %>
        <% end %>
        <%= button_to "Archive", archive_admin_message_path(message), method: :patch, class: "min-h-11 border px-4", form: { data: { turbo_confirm: "Archive this message?" } } %>
        <% if message.failed? %>
          <%= button_to "Retry email", retry_email_admin_message_path(message), method: :post, class: "min-h-11 border px-4" %>
        <% end %>
      </div>
    </article>
  <% end %>

  <% if @messages.empty? %>
    <p class="border p-6">No contact messages.</p>
  <% end %>
</div>
```

```erb
<%# app/views/admin/messages/show.html.erb %>
<article class="mx-auto max-w-3xl">
  <%= link_to "← Inbox", admin_messages_path, class: "underline" %>
  <header class="mt-6 border-b pb-6">
    <p class="break-words"><%= @message.sender_name %> · <%= mail_to @message.sender_email %></p>
    <h1 class="mt-2 break-words text-3xl font-bold"><%= @message.subject %></h1>
    <p class="mt-2"><%= l(@message.created_at, format: :long) %></p>
    <p class="mt-2">Inbox: <%= @message.state %> · Email: <%= @message.email_delivery_state %></p>
    <% if @message.last_delivery_error.present? %>
      <p class="mt-2" role="status"><%= @message.last_delivery_error %></p>
    <% end %>
  </header>

  <div class="prose mt-6 max-w-none whitespace-pre-wrap break-words"><%= @message.body %></div>

  <div class="mt-8 flex flex-wrap gap-3">
    <% if @message.unread? %>
      <%= button_to "Mark read", mark_read_admin_message_path(@message), method: :patch, class: "min-h-11 border px-4" %>
    <% else %>
      <%= button_to "Mark unread", mark_unread_admin_message_path(@message), method: :patch, class: "min-h-11 border px-4" %>
    <% end %>
    <%= button_to "Archive", archive_admin_message_path(@message), method: :patch, class: "min-h-11 border px-4", form: { data: { turbo_confirm: "Archive this message?" } } %>
    <% if @message.failed? %>
      <%= button_to "Retry email", retry_email_admin_message_path(@message), method: :post, class: "min-h-11 border px-4" %>
    <% end %>
  </div>
</article>
```

The body uses escaped ERB output plus `whitespace-pre-wrap`; it is never passed through Markdown or `html_safe`.

- [ ] **Step 6: Add actionable dashboard counts**

Add these assignments to `Admin::DashboardController#show` without removing Phase 5's count, draft, and scheduled queries:

```ruby
@unread_message_count = ContactMessage.unread.count
@failed_delivery_count = ContactMessage.failed.count
```

Add this card to the existing dashboard action grid in `app/views/admin/dashboard/show.html.erb`:

```erb
<%= link_to admin_messages_path, class: "block min-h-24 border p-4" do %>
  <span class="block text-2xl font-bold"><%= @unread_message_count %></span>
  <span>Unread messages</span>
  <% if @failed_delivery_count.positive? %>
    <span class="mt-2 block"><%= pluralize(@failed_delivery_count, "failed email delivery") %></span>
  <% end %>
<% end %>
```

- [ ] **Step 7: Run focused admin and delivery tests**

Run: `bin/rails test test/requests/admin/messages_test.rb test/models/contact_message_test.rb test/jobs/contact_notification_job_test.rb`

Expected: all tests pass; two retry requests enqueue exactly one job and retain the original message fields.

- [ ] **Step 8: Commit the owner inbox**

```bash
git add config/routes.rb app/controllers/admin/messages_controller.rb app/views/admin/messages app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb test/requests/admin/messages_test.rb
git commit -m "feat: add contact inbox and safe retries"
```

---

### Task 5: Prove the End-to-End Flow and Accept the Phase

**Files:**

- Create: `test/system/contact_flow_test.rb`

**Interfaces:**

- Consumes: public contact routes, after-commit job, admin authentication helper, and admin inbox routes.
- Produces: one browser-level regression covering localized submission and owner visibility.

- [ ] **Step 1: Write the failing system test**

```ruby
# test/system/contact_flow_test.rb
require "application_system_test_case"

class ContactFlowTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "visitor submits a localized message and owner manages it on a phone" do
    resize_to 320, 700
    visit localized_contact_path(locale: :fr)

    fill_in "Nom", with: "Ada Lovelace"
    fill_in "Adresse e-mail", with: "ada@example.test"
    fill_in "Objet", with: "Projet Rails"
    fill_in "Message", with: "Parlons de mon projet."

    assert_difference("ContactMessage.count", 1) do
      click_button "Envoyer le message"
      assert_text "Votre message a été enregistré."
    end

    message = ContactMessage.order(:id).last
    assert message.pending?

    sign_in_owner
    visit admin_messages_path
    within "article[data-message-id='#{message.id}']" do
      assert_text "Projet Rails"
      assert_text "pending"
      click_link "Projet Rails"
    end

    assert_text "Parlons de mon projet."
    click_button "Mark read"
    assert_text "Message marked as read."
    assert message.reload.read?
  end
end
```

- [ ] **Step 2: Run the system test before final polish**

Run: `bin/rails test:system TEST=test/system/contact_flow_test.rb`

Expected: PASS if Tasks 1–4 are complete; otherwise the failure identifies the unfinished browser-visible behavior.

- [ ] **Step 3: Re-run the focused system test at phone size**

Run: `bin/rails test:system TEST=test/system/contact_flow_test.rb`

Expected: PASS at 320×700; the public receipt appears after persistence and the owner can read and mark the same row.

- [ ] **Step 4: Run all Phase 6 automated checks**

```bash
bin/rails test \
  test/models/contact_message_test.rb \
  test/mailers/contact_mailer_test.rb \
  test/jobs/contact_notification_job_test.rb \
  test/requests/public/contact_messages_test.rb \
  test/requests/admin/messages_test.rb
bin/rails test:system TEST=test/system/contact_flow_test.rb
bin/rails test
bin/rails test:system
```

Expected: every command exits 0 with no failures or errors.

- [ ] **Step 5: Perform delivery and privacy acceptance checks**

Run `bin/dev` in one terminal and `bin/jobs start` in a second terminal, submit one message at `/en/contact`, and verify all of the following:

1. The browser receives receipt copy immediately after the row commits, without waiting for SMTP.
2. The queued job argument shown by the queue contains only the integer `contact_message_id`.
3. Development request and job logs contain neither the submitted body nor the body embedded in an exception.
4. A successful SMTP delivery sets `email_delivery_state` to `delivered`, records `delivered_at`, clears `last_delivery_error`, and makes a later queued attempt a no-op.
5. With deliberately invalid SMTP credentials, the saved row remains, changes to `failed`, stores only `<ExceptionClass>: delivery failed`, and exposes **Retry email** in `/admin/messages`.
6. Two rapid retry submissions enqueue once; the row's sender, subject, body, and original `created_at` remain unchanged.
7. At 320 CSS pixels and 200% zoom, form fields, cards, message text, and action buttons do not overflow horizontally; every action works by keyboard and touch without hover.

Expected: all seven observations hold. Restore valid SMTP credentials after the failure check.

- [ ] **Step 6: Commit the system proof and tag the accepted phase**

```bash
git add test/system/contact_flow_test.rb
git commit -m "test: cover contact flow end to end"
git tag portfolio-v4-phase-6
```

Do not create the tag until every automated command and all seven manual observations pass.

## Phase 6 Acceptance Checklist

- [ ] Contact rows enforce required fields, bounded lengths, valid enums, and database state constraints.
- [ ] New valid messages enqueue one ID-only job after commit; invalid, honeypot, and throttled submissions enqueue none.
- [ ] English, French, and Vietnamese forms preserve entered content and show localized feedback.
- [ ] The public response claims persistence only, never delivery success.
- [ ] Successful delivery records `delivered_at`; failure preserves the row and stores no exception message or contact body.
- [ ] Request filtering and job serialization keep the message body out of application logs and queue payloads.
- [ ] Admin routes require the authenticated owner and support read, unread, archive, and retry actions.
- [ ] Retry is idempotent for failed-to-pending and delivered records and never edits the original message content.
- [ ] Inbox cards and detail actions work at 320 CSS pixels, 200% zoom, keyboard-only, and touch-only.
- [ ] `bin/rails test` and `bin/rails test:system` pass before tagging `portfolio-v4-phase-6`.

## Risks and Verification Points

- **SMTP exactly-once ceiling:** SMTP has no universal idempotency key. The row lock prevents concurrent duplicate jobs and delivered rows are skipped, but a process death between provider acceptance and `mark_delivered!` can still duplicate mail. Verify provider behavior before adding provider-specific infrastructure.
- **Rate-limit cache scope:** The native limiter uses `Rails.cache`; production must use the generated shared Solid Cache configuration rather than a per-process memory store. Verify two requests served by different Puma workers share the same counter during deployment checks.
- **SQLite lock duration:** The job holds one contact-message row transaction while SMTP responds. Contact volume is intentionally low; revisit only if measured lock contention affects unrelated writes.
- **Privacy regression:** Keep the job argument ID-only and `:body` filtered. Re-run the parameter-filter and serialized-argument tests whenever contact parameters or job signatures change.
