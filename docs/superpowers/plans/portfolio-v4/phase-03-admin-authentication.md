# Phase 3 Admin Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the single portfolio owner password-plus-TOTP authentication, one-use recovery codes, expiring rotated database sessions, generic password reset, and a protected mobile-first `/admin` shell.

**Architecture:** `AdminUser` owns credentials and the transactional provisioning/password-reset workflows. `AdminSession` is a database record whose ID is carried in Rails' signed cookie jar; a ten-minute `pending_totp` record is destroyed and replaced by a twelve-hour `verified` record after TOTP or recovery succeeds. Controllers stay HTTP-focused through `Current` and `Admin::Authentication`, while Rails 8.1 supplies secure-password reset tokens, `params.expect`, controller rate limiting, signed cookies, CSRF protection, Action Mailer, encrypted fixtures, and Active Record Encryption; reset tokens are minted while queued mail is rendered so no reset bearer is serialized into Solid Queue, and `rotp` is the only new application dependency.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, SQLite, Active Record Encryption, `bcrypt`, ROTP 6.3.x, Action Mailer, Active Job, Hotwire, Tailwind CSS, Minitest, Capybara

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

**Parent plan:** `docs/superpowers/plans/2026-09-02-portfolio-v4-implementation.md` — Phase 3 contract is immutable; this plan only expands it.

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
- Keep authentication controllers on CRUD actions and HTTP concerns. Credential provisioning, password reset, TOTP/recovery transitions, and session expiration belong to `AdminUser` or `AdminSession`; do not add service objects.
- Use Rails' signed cookie jar for the database session ID, `params.expect` for required structured form input, and encrypted Rails fixtures for the shared test owner.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.
- In this agent environment, invoke Bundler with `mise exec -- bundle ...` and Rails with `mise exec -- ruby bin/rails ...` so `.ruby-version` resolves to Ruby 4.0.6; the deployment-facing command remains plain `bin/rails admin:create` inside the application image or an activated developer shell.

## Assumptions and Fixed Security Decisions

- Phases 1 and 2 are accepted. Their public routes, `ApplicationController`, public layout, theme bootstrap, content models, and locale behavior remain unchanged.
- Rails' `ActionController::Base` forgery protection remains enabled outside the test environment; no authentication controller skips it.
- There is exactly one `AdminUser`, enforced in SQLite by a constant `singleton_guard = 1` plus a unique index—not only by application validation.
- Passwords are at least 14 characters and are hashed by `has_secure_password`/bcrypt.
- TOTP uses SHA-1, six digits, a 30-second interval, and permits one interval of clock drift in either direction. `last_totp_at` makes each accepted time step one-use.
- Each credential rotation creates ten 80-bit recovery codes. Only keyed SHA-256 digests are persisted; matching and deletion happen under a row lock.
- Password-stage sessions expire after 10 minutes. Fully verified sessions expire after 12 hours. Expiration is absolute rather than sliding.
- The cookie name is `admin_session`, its signed value is the `AdminSession` ID, its path is `/admin`, and it is `HttpOnly`, `SameSite=Strict`, and `Secure` in production or on HTTPS requests. The database record and Rails signature are both required for authentication.
- Password reset tokens use Rails 8.1's native `has_secure_password reset_token:` support, expire 30 minutes after the queued email is rendered, and become invalid when the password digest changes. A successful password update and revocation of every `AdminSession` happen in one transaction and do not disable TOTP.
- Reset tokens are copied from email into a POSTed form field; they never appear in a request URL, browser history, referrer, Rails request line, or reverse-proxy access log.
- Attempt limits are: five password attempts per IP per 15 minutes, five TOTP attempts per IP per 10 minutes, five recovery attempts per IP per 10 minutes, and three reset requests per IP per hour.
- Authentication errors use one message: `Email, password, or verification code is invalid.` Reset requests always respond: `If that email is the owner account, a reset link has been sent.`
- `admin:create` is non-interactive. It consumes `ADMIN_EMAIL` and `ADMIN_PASSWORD`, creates or resets the sole owner, rotates TOTP/recovery credentials, revokes sessions, and prints the provisioning URI and plaintext recovery codes exactly once.

## Parent Interfaces Preserved

- `Current.admin_user` returns the owner only for a live `verified` `AdminSession`; it returns `nil` during the password-only stage.
- `Admin::BaseController#require_admin!` guards every dashboard and later CMS controller. Keep this established cross-phase bang method unchanged; new internal methods do not use unpaired bangs.
- `AdminUser#verify_totp(code) -> Boolean` accepts a fresh TOTP step and rejects malformed, invalid, or replayed codes.
- `AdminUser#consume_recovery_code(code) -> Boolean` atomically consumes one matching code.
- `AdminSession.active.find_by(id:)` resumes the signed `admin_session` cookie only while its database record is unexpired.
- `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails admin:create` is the deployment interface. There is no registration route.

The repository already uses database foreign keys for local SQLite associations, so `admin_sessions.admin_user_id` follows that project convention. The 37signals no-foreign-key choice solves import, export, and sharding constraints this single-owner application does not have.

## File Map

| File                                                                                                 | Responsibility                                                                              |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `Gemfile`, `Gemfile.lock`                                                                            | Enable bcrypt secure passwords and add ROTP.                                                |
| `config/initializers/active_record_encryption.rb`                                                    | Derive non-production encryption keys and require three production environment secrets.     |
| `config/initializers/filter_parameter_logging.rb`                                                    | Filter passwords, reset tokens, and the actual nested TOTP/recovery parameter scopes.       |
| `config/initializers/content_security_policy.rb`                                                     | Same-origin CSP with per-request script nonces.                                             |
| `db/migrate/*_create_admin_users.rb`                                                                 | Single-owner credentials, encrypted-secret storage, recovery digests, and replay timestamp. |
| `db/migrate/*_create_admin_sessions.rb`                                                              | Pending/verified session records and absolute expiry.                                       |
| `app/models/admin_user.rb`                                                                           | Password, TOTP, recovery codes, provisioning, atomic reset, and expiring reset token.       |
| `app/models/admin_session.rb`                                                                        | Pending/verified database sessions with absolute expiration.                                |
| `app/models/current.rb`                                                                              | Request-local verified owner/session interface.                                             |
| `app/controllers/concerns/admin/authentication.rb`                                                   | Resume, rotate, set, and clear the admin cookie/session.                                    |
| `app/controllers/admin/authentication_controller.rb`                                                 | Shared unprotected admin-auth base and authentication layout.                               |
| `app/controllers/admin/base_controller.rb`                                                           | `require_admin!` authorization boundary for Phase 3 and all later admin controllers.        |
| `app/controllers/admin/sessions_controller.rb`                                                       | Password stage and explicit logout.                                                         |
| `app/controllers/admin/totp_challenges_controller.rb`                                                | TOTP stage and replay-safe verification.                                                    |
| `app/controllers/admin/recovery_challenges_controller.rb`                                            | One-use recovery-code stage.                                                                |
| `app/controllers/admin/password_resets_controller.rb`                                                | Generic reset request and expiring-token password update.                                   |
| `app/controllers/admin/dashboard_controller.rb`                                                      | First protected admin endpoint.                                                             |
| `app/mailers/admin_password_mailer.rb` and views                                                     | Deliver a reset code plus a clean, token-free form URL.                                     |
| `app/views/layouts/admin_authentication.html.erb`                                                    | Narrow, mobile-first sign-in/reset shell.                                                   |
| `app/views/layouts/admin.html.erb`                                                                   | Protected mobile-first dashboard shell consumed by later phases.                            |
| `app/views/admin/**`                                                                                 | Password, second-factor, recovery, reset, and dashboard HTML forms/pages.                   |
| `config/routes.rb`                                                                                   | Singular auth/reset resources and protected `/admin` root; no registration resource.        |
| `lib/tasks/admin.rake`                                                                               | Non-interactive owner creation/credential reset.                                            |
| `test/fixtures/admin_users.yml`                                                                      | Rails-encrypted owner fixture shared by authentication tests.                               |
| `test/support/admin_authentication_test_helper.rb`                                                   | Request/system sign-in helpers built on the owner fixture.                                  |
| `test/models/admin_user_test.rb`, `test/models/admin_session_test.rb`, `test/models/current_test.rb` | Credential and session invariants.                                                          |
| `test/requests/admin/authentication_test.rb`, `test/requests/admin/password_resets_test.rb`          | Authorization, rotation, throttling, generic responses, reset expiry, and cookie flags.     |
| `test/mailers/admin_password_mailer_test.rb`                                                         | Reset mail content and URL.                                                                 |
| `test/tasks/admin_create_test.rb`                                                                    | Environment contract, single-owner reset, and one-time enrollment output.                   |
| `test/system/admin_authentication_test.rb`                                                           | Browser-level password + TOTP/recovery/logout flows.                                        |

---

### Task 1: Add the encrypted single-owner credential model

**Files:**

- Modify: `Gemfile`
- Modify: `Gemfile.lock`
- Create: `config/initializers/active_record_encryption.rb`
- Modify: `config/initializers/filter_parameter_logging.rb`
- Create: `db/migrate/*_create_admin_users.rb`
- Create: `app/models/admin_user.rb`
- Create: `test/fixtures/admin_users.yml`
- Create: `test/support/admin_authentication_test_helper.rb`
- Modify: `config/environments/test.rb`
- Modify: `test/test_helper.rb`
- Modify: `test/application_system_test_case.rb`
- Create: `test/models/admin_user_test.rb`
- Modify: `db/schema.rb` (generated)

**Interfaces:**

- Consumes: Rails' `has_secure_password`, Active Record Encryption, `Rails.application.key_generator`, and the Phase 1 test harness.
- Produces: `AdminUser#verify_totp(code) -> Boolean`, `AdminUser#consume_recovery_code(code) -> Boolean`, `AdminUser#replace_recovery_codes -> Array<String>`, `AdminUser#totp_provisioning_uri -> String`, `AdminUser#password_reset_token -> String`, and `AdminUser.find_by_password_reset_token(token) -> AdminUser?`.

- [ ] **Step 1: Add dependencies and install them**

Ensure these exact entries are active in `Gemfile`; retain the Phase 2 `commonmarker` entry and every generated Rails dependency:

```ruby
gem "bcrypt", "~> 3.1"
gem "rotp", "~> 6.3"
```

Run with the repository's Ruby 4.0.6 runtime:

```bash
mise exec -- bundle install
```

Expected: `bundle check` prints `The Gemfile's dependencies are satisfied`; `Gemfile.lock` contains `bcrypt` and `rotp`.

- [ ] **Step 2: Generate the migration and add the encrypted owner fixture/helpers**

Generate a migration version newer than the existing Phase 2 migrations:

```bash
mise exec -- ruby bin/rails generate migration CreateAdminUsers
```

Replace the generated migration body in `db/migrate/*_create_admin_users.rb` with:

```ruby
class CreateAdminUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.text :totp_secret, null: false
      t.json :recovery_code_digests, null: false, default: []
      t.datetime :last_totp_at
      t.integer :singleton_guard, null: false, default: 1
      t.timestamps
    end

    add_index :admin_users, :email, unique: true
    add_index :admin_users, :singleton_guard, unique: true
    add_check_constraint :admin_users, "singleton_guard = 1", name: "admin_users_single_owner"
  end
end
```

Enable Rails' native encrypted-fixture support inside the `Rails.application.configure` block in `config/environments/test.rb`:

```ruby
config.active_record.encryption.encrypt_fixtures = true
```

Create `test/fixtures/admin_users.yml`:

```yaml
owner:
  email: owner@example.com
  password_digest: <%= BCrypt::Password.create("correct horse battery staple", cost: BCrypt::Engine::MIN_COST) %>
  totp_secret: JBSWY3DPEHPK3PXP
  recovery_code_digests: []
  singleton_guard: 1
```

Rails encrypts `totp_secret` while loading this fixture; plaintext is never inserted into the test database.

Create `test/support/admin_authentication_test_helper.rb`:

```ruby
module AdminAuthenticationTestHelper
  TEST_PASSWORD = "correct horse battery staple"
  TEST_TOTP_SECRET = "JBSWY3DPEHPK3PXP"

  def sign_in_as_admin
    user = admin_users(:owner)
    post admin_session_path, params: {
      admin_login: { email: user.email, password: TEST_PASSWORD }
    }
    post admin_totp_challenge_path, params: {
      totp: { code: ROTP::TOTP.new(user.totp_secret).now }
    }
    user
  end

  def sign_out_admin
    delete admin_session_path
  end

  def sign_in_owner
    user = admin_users(:owner)
    visit new_admin_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: TEST_PASSWORD
    click_button "Continue"
    fill_in "Six-digit code", with: ROTP::TOTP.new(user.totp_secret).now
    click_button "Verify"
    user
  end
end
```

At the end of `test/test_helper.rb`, load and mix in support helpers:

```ruby
Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

class ActiveSupport::TestCase
  include AdminAuthenticationTestHelper
end

class ActionDispatch::IntegrationTest
  include AdminAuthenticationTestHelper
end
```

Add the system helper to `test/application_system_test_case.rb`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AdminAuthenticationTestHelper
end
```

The helper contracts used by later phases are `sign_in_as_admin` for request tests, `sign_out_admin` for request tests, and `sign_in_owner` for browser system tests.

- [ ] **Step 3: Write failing `AdminUser` tests**

Create `test/models/admin_user_test.rb`:

```ruby
require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "normalizes email and authenticates a fourteen character password" do
    user = admin_users(:owner)
    user.update!(email: "  OWNER@Example.COM ")

    assert_equal "owner@example.com", user.email
    assert_equal user, AdminUser.authenticate_by(email: "owner@example.com", password: TEST_PASSWORD)
    assert_not_equal TEST_PASSWORD, user.password_digest
  end

  test "rejects short passwords and a second owner" do
    short = AdminUser.new(email: "other@example.com", password: "too short", totp_secret: TEST_TOTP_SECRET)

    assert_not short.valid?
    assert_includes short.errors[:password], "is too short (minimum is 14 characters)"
    assert_raises(ActiveRecord::RecordNotUnique) do
      AdminUser.create!(email: "other@example.com", password: TEST_PASSWORD, totp_secret: TEST_TOTP_SECRET)
    end
  end

  test "stores the TOTP secret as ciphertext" do
    user = admin_users(:owner)
    stored = AdminUser.connection.select_value(
      AdminUser.sanitize_sql_array(["SELECT totp_secret FROM admin_users WHERE id = ?", user.id])
    )

    assert_equal TEST_TOTP_SECRET, user.reload.totp_secret
    assert_not_equal TEST_TOTP_SECRET, stored
    assert_not_includes stored, TEST_TOTP_SECRET
  end

  test "accepts a current TOTP once and rejects replay" do
    travel_to Time.zone.parse("2026-09-02 12:00:00 UTC") do
      user = admin_users(:owner)
      code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)

      assert_equal true, user.verify_totp(code)
      assert_equal false, user.verify_totp(code)
    end
  end

  test "accepts one interval of TOTP clock drift and rejects malformed input" do
    travel_to Time.zone.parse("2026-09-02 12:00:00 UTC") do
      user = admin_users(:owner)
      totp = ROTP::TOTP.new(TEST_TOTP_SECRET)
      previous_code = totp.at(30.seconds.ago)
      too_old_code = totp.at(60.seconds.ago)

      assert_equal true, user.verify_totp(previous_code)
      assert_equal false, user.verify_totp(too_old_code)
      assert_equal false, user.verify_totp("12-abcd")
      assert_equal false, user.verify_totp(nil)
    end
  end

  test "recovery codes are high entropy digests and each code works once" do
    user = admin_users(:owner)
    codes = user.replace_recovery_codes
    stored = user.reload.recovery_code_digests.to_json

    assert_equal 10, codes.length
    assert_equal 10, codes.uniq.length
    assert codes.all? { |code| code.match?(/\A[0-9A-F]{4}(?:-[0-9A-F]{4}){4}\z/) }
    codes.each { |code| assert_not_includes stored, code.delete("-") }
    assert_equal true, user.consume_recovery_code(codes.first.downcase)
    assert_equal false, user.consume_recovery_code(codes.first)
    assert_equal 9, user.reload.recovery_code_digests.length
    assert_equal false, user.consume_recovery_code("#{codes.second}!not-valid")
  end

  test "password reset token expires and changing the password invalidates it" do
    user = admin_users(:owner)
    token = user.password_reset_token

    assert_equal user, AdminUser.find_by_password_reset_token(token)
    travel 31.minutes
    assert_nil AdminUser.find_by_password_reset_token(token)

    travel_back
    token = user.password_reset_token
    user.update!(password: "a different secure password", password_confirmation: "a different secure password")
    assert_nil AdminUser.find_by_password_reset_token(token)
  end
end
```

- [ ] **Step 4: Run the model test and verify red**

Run:

```bash
mise exec -- ruby bin/rails db:migrate
mise exec -- ruby bin/rails test test/models/admin_user_test.rb
```

Expected: migration succeeds, then tests fail because `AdminUser` and its credential methods do not exist.

- [ ] **Step 5: Configure encryption and parameter filtering**

Create `config/initializers/active_record_encryption.rb`:

```ruby
keys = if Rails.env.production?
  {
    primary_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"),
    deterministic_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"),
    key_derivation_salt: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
  }
else
  generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
  {
    primary_key: generator.generate_key("active-record-encryption-primary", 32),
    deterministic_key: generator.generate_key("active-record-encryption-deterministic", 32),
    key_derivation_salt: generator.generate_key("active-record-encryption-salt", 32)
  }
end

ActiveRecord::Encryption.configure(**keys)
```

Call `ActiveRecord::Encryption.configure` directly here. Assigning only to `Rails.application.config.active_record.encryption` from an application initializer is too late because the Active Record railtie has already copied that configuration into the encryption context.

The generated filter list already covers password keys through `:passw`, reset tokens through `:token`, and TOTP keys through `:otp`. Add only the missing recovery-code scope:

```ruby
Rails.application.config.filter_parameters << :recovery
```

Do not generate or persist production encryption values in this phase. Phase 8 owns generation and installation of the three required deployment secrets before the production application boots.

- [ ] **Step 6: Implement `AdminUser` minimally**

Create `app/models/admin_user.rb`:

```ruby
class AdminUser < ApplicationRecord
  RECOVERY_CODE_COUNT = 10
  RECOVERY_CODE_BYTES = 10
  TOTP_ISSUER = "Portfolio"

  has_secure_password reset_token: { expires_in: 30.minutes }
  encrypts :totp_secret

  has_many :admin_sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 14 }, if: -> { password.present? }
  validates :totp_secret, presence: true
  validates :singleton_guard, inclusion: { in: [1] }

  class << self
    def generate_recovery_code
      SecureRandom.hex(RECOVERY_CODE_BYTES).upcase.scan(/.{4}/).join("-")
    end

    def digest_recovery_code(code)
      normalized = code.to_s.upcase.delete(" \t-")
      key = Rails.application.key_generator.generate_key("admin-recovery-codes", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
    end
  end

  def verify_totp(code)
    normalized = code.to_s.delete(" \t-")
    return false unless normalized.match?(/\A\d{6}\z/)

    with_lock do
      options = {
        at: Time.current,
        drift_behind: 30,
        drift_ahead: 30
      }
      options[:after] = last_totp_at.to_i if last_totp_at
      verified_at = totp.verify(normalized, **options)
      next false unless verified_at

      update!(last_totp_at: Time.zone.at(verified_at))
      true
    end
  end

  def replace_recovery_codes
    codes = Array.new(RECOVERY_CODE_COUNT) { self.class.generate_recovery_code }
    update!(recovery_code_digests: codes.map { |code| self.class.digest_recovery_code(code) })
    codes
  end

  def consume_recovery_code(code)
    normalized = code.to_s.upcase.delete(" \t-")
    return false unless normalized.match?(/\A[0-9A-F]{20}\z/)

    candidate = self.class.digest_recovery_code(normalized)

    with_lock do
      index = recovery_code_digests.index do |digest|
        ActiveSupport::SecurityUtils.secure_compare(candidate, digest)
      end
      next false unless index

      update!(recovery_code_digests: recovery_code_digests.each_with_index.filter_map { |digest, i| digest unless i == index })
      true
    end
  end

  def totp_provisioning_uri
    totp.provisioning_uri(email)
  end

  private

  def totp
    ROTP::TOTP.new(totp_secret, issuer: TOTP_ISSUER, digits: 6, interval: 30)
  end
end
```

- [ ] **Step 7: Run focused tests and inspect the schema**

Run:

```bash
mise exec -- ruby bin/rails test test/models/admin_user_test.rb
mise exec -- ruby bin/rails runner 'u = AdminUser.first; abort("plaintext TOTP persisted") if u && u.attributes_before_type_cast.fetch("totp_secret").include?(u.totp_secret)'
```

Expected: seven tests pass; the runner exits zero without output.

- [ ] **Step 8: Commit the credential model**

```bash
git add Gemfile Gemfile.lock config/environments/test.rb config/initializers/active_record_encryption.rb config/initializers/filter_parameter_logging.rb db/migrate/*_create_admin_users.rb db/schema.rb app/models/admin_user.rb test/fixtures/admin_users.yml test/test_helper.rb test/application_system_test_case.rb test/support/admin_authentication_test_helper.rb test/models/admin_user_test.rb
git commit -m "feat: add encrypted owner credentials"
```

---

### Task 2: Add expiring database-backed admin sessions

**Files:**

- Create: `db/migrate/*_create_admin_sessions.rb`
- Create: `app/models/admin_session.rb`
- Create or modify: `app/models/current.rb`
- Create: `test/models/admin_session_test.rb`
- Create: `test/models/current_test.rb`
- Modify: `db/schema.rb` (generated)

**Interfaces:**

- Consumes: persisted `AdminUser` and Rails' signed cookie/session primitives.
- Produces: `AdminSession.active`, `AdminSession::COOKIE_NAME`, association-based pending/verified session creation, and verified-only `Current.admin_user`.

- [ ] **Step 1: Generate and write the session migration**

Generate a migration version newer than the existing Phase 2 migrations and the Task 1 migration:

```bash
mise exec -- ruby bin/rails generate migration CreateAdminSessions
```

Replace the generated migration body in `db/migrate/*_create_admin_sessions.rb` with:

```ruby
class CreateAdminSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :state, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :admin_sessions, :expires_at
    add_check_constraint :admin_sessions,
      "state IN ('pending_totp', 'verified')",
      name: "admin_sessions_valid_state"
  end
end
```

- [ ] **Step 2: Write failing session and `Current` tests**

Create `test/models/admin_session_test.rb`:

```ruby
require "test_helper"

class AdminSessionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { @user = admin_users(:owner) }

  test "pending sessions expire after ten minutes" do
    record = @user.admin_sessions.create!(state: :pending_totp)

    assert_equal 10.minutes.from_now.to_i, record.expires_at.to_i
    assert_includes AdminSession.active, record
  end

  test "verified sessions expire after twelve hours" do
    record = @user.admin_sessions.create!(state: :verified)

    assert_predicate record, :verified?
    assert_equal 12.hours.from_now.to_i, record.expires_at.to_i
  end

  test "active excludes expired sessions" do
    record = @user.admin_sessions.create!(state: :pending_totp)

    travel 11.minutes
    assert_not_includes AdminSession.active, record
  end
end
```

Create `test/models/current_test.rb`:

```ruby
require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "exposes admin_user only after second factor verification" do
    user = admin_users(:owner)
    pending = user.admin_sessions.create!(state: :pending_totp)
    verified = user.admin_sessions.create!(state: :verified)

    Current.admin_session = pending
    assert_nil Current.admin_user

    Current.admin_session = verified
    assert_equal user, Current.admin_user
  end
end
```

- [ ] **Step 3: Run the focused tests and verify red**

Run:

```bash
mise exec -- ruby bin/rails db:migrate
mise exec -- ruby bin/rails test test/models/admin_session_test.rb test/models/current_test.rb
```

Expected: tests fail because `AdminSession` and `Current.admin_session` do not exist.

- [ ] **Step 4: Implement session state and absolute expiration**

Create `app/models/admin_session.rb`:

```ruby
class AdminSession < ApplicationRecord
  COOKIE_NAME = :admin_session
  PENDING_LIFETIME = 10.minutes
  VERIFIED_LIFETIME = 12.hours

  belongs_to :admin_user

  enum :state, { pending_totp: "pending_totp", verified: "verified" }, validate: true

  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  before_validation :set_expiration, on: :create

  private

  def set_expiration
    self.expires_at ||= (verified? ? VERIFIED_LIFETIME : PENDING_LIFETIME).from_now
  end
end
```

Create or replace `app/models/current.rb` with:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :admin_session

  def admin_user
    admin_session&.verified? ? admin_session.admin_user : nil
  end
end
```

- [ ] **Step 5: Run tests and inspect the session schema**

Run:

```bash
mise exec -- ruby bin/rails test test/models/admin_session_test.rb test/models/current_test.rb
mise exec -- ruby bin/rails runner 'columns = AdminSession.column_names; abort("custom bearer columns remain") if columns.intersect?(%w[token_id token_digest])'
```

Expected: four tests pass; the runner exits zero without output.

- [ ] **Step 6: Commit session primitives**

```bash
git add db/migrate/*_create_admin_sessions.rb db/schema.rb app/models/admin_session.rb app/models/current.rb test/models/admin_session_test.rb test/models/current_test.rb
git commit -m "feat: add expiring admin sessions"
```

---

### Task 3: Build password, TOTP, recovery, logout, and protected dashboard flows

**Files:**

- Modify: `config/routes.rb`
- Modify: `config/environments/test.rb`
- Create: `app/controllers/concerns/admin/authentication.rb`
- Create: `app/controllers/admin/authentication_controller.rb`
- Create: `app/controllers/admin/base_controller.rb`
- Create: `app/controllers/admin/sessions_controller.rb`
- Create: `app/controllers/admin/totp_challenges_controller.rb`
- Create: `app/controllers/admin/recovery_challenges_controller.rb`
- Create: `app/controllers/admin/dashboard_controller.rb`
- Create: `app/views/layouts/admin_authentication.html.erb`
- Create: `app/views/layouts/admin.html.erb`
- Create: `app/views/admin/sessions/new.html.erb`
- Create: `app/views/admin/totp_challenges/show.html.erb`
- Create: `app/views/admin/recovery_challenges/show.html.erb`
- Create: `app/views/admin/dashboard/show.html.erb`
- Create: `test/requests/admin/authentication_test.rb`

**Interfaces:**

- Consumes: `AdminUser.authenticate_by`, TOTP/recovery methods, `AdminSession.active`, Rails' signed cookie jar, and the Phase 1 application layout/theme assets.
- Produces: `Current.admin_user`, signed-cookie database-session authentication, `Admin::BaseController#require_admin!`, protected `admin_root_path`, and reusable admin layouts for Phase 4.

- [ ] **Step 1: Add only the Phase 3 admin routes**

Inside `Rails.application.routes.draw`, add this namespace without changing public routes:

```ruby
namespace :admin do
  root "dashboard#show"
  resource :session, only: %i[new create destroy]
  resource :totp_challenge, only: %i[show create]
  resource :recovery_challenge, only: %i[show create]
  resource :password_reset, only: %i[new create edit update]
end
```

Do not add `resources :admin_users`, `sign_up`, `registration`, or any public account route.

Make controller throttling testable by setting this exact cache store in `config/environments/test.rb`:

```ruby
config.cache_store = :memory_store
```

- [ ] **Step 2: Write failing authentication request tests**

Create `test/requests/admin/authentication_test.rb`:

```ruby
require "test_helper"

class Admin::AuthenticationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    @user = admin_users(:owner)
    @recovery_codes = @user.replace_recovery_codes
  end

  teardown do
    Rails.cache.clear
    Current.reset
  end

  test "anonymous and password-only requests cannot enter admin" do
    get admin_root_path
    assert_redirected_to new_admin_session_path

    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    assert_redirected_to admin_totp_challenge_path

    get admin_root_path
    assert_redirected_to admin_totp_challenge_path
    assert_nil Current.admin_user
  end

  test "shared request helper completes both authentication stages" do
    sign_in_as_admin

    assert_predicate AdminSession.find(signed_admin_session_id), :verified?
    get admin_root_path
    assert_response :success
  end

  test "invalid email and invalid password return the same response" do
    post admin_session_path, params: { admin_login: { email: "missing@example.com", password: TEST_PASSWORD } }
    missing_status = response.status
    missing_message = flash[:alert]

    post admin_session_path, params: { admin_login: { email: @user.email, password: "wrong password value" } }

    assert_equal missing_status, response.status
    assert_equal missing_message, flash[:alert]
    assert_equal "Email, password, or verification code is invalid.", flash[:alert]
  end

  test "fresh TOTP rotates the pending session into a verified session" do
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    pending_cookie = cookies[AdminSession::COOKIE_NAME]
    pending = AdminSession.find(signed_admin_session_id)
    assert_predicate pending, :pending_totp?

    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    post admin_totp_challenge_path, params: { totp: { code: code } }

    assert_redirected_to admin_root_path
    verified_cookie = cookies[AdminSession::COOKIE_NAME]
    verified = AdminSession.find(signed_admin_session_id)
    assert_not_equal pending_cookie, verified_cookie
    assert_not AdminSession.exists?(pending.id)
    assert_predicate verified, :verified?

    get admin_root_path
    assert_response :success
  end

  test "TOTP replay cannot create a second verified session" do
    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    sign_in_with_password
    post admin_totp_challenge_path, params: { totp: { code: code } }
    delete admin_session_path

    sign_in_with_password
    post admin_totp_challenge_path, params: { totp: { code: code } }

    assert_response :unprocessable_entity
    assert_equal "Email, password, or verification code is invalid.", flash[:alert]
    assert_predicate AdminSession.find(signed_admin_session_id), :pending_totp?
  end

  test "recovery code is one-use and rotates into a verified session" do
    sign_in_with_password
    post admin_recovery_challenge_path, params: { recovery: { code: @recovery_codes.first } }

    assert_redirected_to admin_root_path
    assert_predicate AdminSession.find(signed_admin_session_id), :verified?
    assert_equal 9, @user.reload.recovery_code_digests.length

    delete admin_session_path
    sign_in_with_password
    post admin_recovery_challenge_path, params: { recovery: { code: @recovery_codes.first } }
    assert_response :unprocessable_entity
  end

  test "logout destroys the database session and cookie" do
    sign_in_with_totp
    session_id = signed_admin_session_id

    delete admin_session_path

    assert_response :see_other
    assert_redirected_to new_admin_session_path
    assert_not AdminSession.exists?(session_id)
    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "tampered signed cookie fails closed" do
    sign_in_with_totp
    cookies[AdminSession::COOKIE_NAME] = "#{cookies[AdminSession::COOKIE_NAME]}tampered"

    get admin_root_path

    assert_redirected_to new_admin_session_path
  end

  test "malformed scoped parameters return bad request without creating a session" do
    assert_no_difference -> { AdminSession.count } do
      post admin_session_path, params: { admin_login: "not-an-object" }
    end

    assert_response :bad_request
  end

  test "expired pending and verified sessions fail closed" do
    sign_in_with_password
    travel 11.minutes
    get admin_totp_challenge_path
    assert_redirected_to new_admin_session_path

    travel_back
    sign_in_with_totp
    travel 13.hours
    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "password attempts are throttled after five failures" do
    5.times do
      post admin_session_path, params: { admin_login: { email: @user.email, password: "incorrect password" } }
      assert_response :unprocessable_entity
    end

    post admin_session_path, params: { admin_login: { email: @user.email, password: "incorrect password" } }
    assert_response :too_many_requests
  end

  test "TOTP attempts are throttled per IP" do
    sign_in_with_password
    5.times do
      post admin_totp_challenge_path, params: { totp: { code: "000000" } }
      assert_response :unprocessable_entity
    end

    post admin_totp_challenge_path, params: { totp: { code: "000000" } }
    assert_response :too_many_requests
  end

  test "recovery attempts are throttled per IP" do
    sign_in_with_password
    5.times do
      post admin_recovery_challenge_path, params: { recovery: { code: "AAAA-BBBB-CCCC-DDDD-0000" } }
      assert_response :unprocessable_entity
    end

    post admin_recovery_challenge_path, params: { recovery: { code: "AAAA-BBBB-CCCC-DDDD-0000" } }
    assert_response :too_many_requests
  end

  test "HTTPS auth cookie is secure strict and HTTP only" do
    https!
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    set_cookie = response.headers["Set-Cookie"]

    assert_includes set_cookie, "admin_session="
    assert_includes set_cookie, "path=/admin"
    assert_includes set_cookie, "HttpOnly"
    assert_includes set_cookie, "SameSite=Strict"
    assert_includes set_cookie, "Secure"
  end

  test "there is no registration route" do
    get "/admin/users/new"
    assert_response :not_found

    post "/admin/users"
    assert_response :not_found
  end

  private

  def signed_admin_session_id
    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar[AdminSession::COOKIE_NAME] = cookies[AdminSession::COOKIE_NAME]
    end.signed[AdminSession::COOKIE_NAME]
  end

  def sign_in_with_password
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
  end

  def sign_in_with_totp
    sign_in_with_password
    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    post admin_totp_challenge_path, params: { totp: { code: code } }
  end
end
```

- [ ] **Step 3: Run the request test and verify red**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/authentication_test.rb
```

Expected: route/controller errors because the authentication controllers do not exist.

- [ ] **Step 4: Implement the shared cookie/session controller concern**

Create `app/controllers/concerns/admin/authentication.rb`:

```ruby
module Admin::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_admin_session
    helper_method :current_admin_user
  end

  private

  def resume_admin_session
    raw_cookie = cookies[AdminSession::COOKIE_NAME]
    session_id = cookies.signed[AdminSession::COOKIE_NAME]
    Current.admin_session = AdminSession.active.includes(:admin_user).find_by(id: session_id)
    delete_admin_cookie if raw_cookie.present? && Current.admin_session.nil?
  end

  def current_admin_user
    Current.admin_user
  end

  def start_new_admin_session_for(admin_user, state:)
    Current.admin_session&.destroy!
    Current.admin_session = nil
    delete_admin_cookie
    reset_session

    record = admin_user.admin_sessions.create!(state: state)
    cookies.signed[AdminSession::COOKIE_NAME] = {
      value: record.id,
      expires: record.expires_at,
      httponly: true,
      secure: Rails.env.production? || request.ssl?,
      same_site: :strict,
      path: "/admin"
    }
    Current.admin_session = record
  end

  def terminate_admin_session
    Current.admin_session&.destroy!
    Current.admin_session = nil
    delete_admin_cookie
    reset_session
  end

  def delete_admin_cookie
    cookies.delete(
      AdminSession::COOKIE_NAME,
      secure: Rails.env.production? || request.ssl?,
      same_site: :strict,
      path: "/admin"
    )
  end
end
```

Create `app/controllers/admin/authentication_controller.rb`:

```ruby
class Admin::AuthenticationController < ApplicationController
  include Admin::Authentication

  layout "admin_authentication"

  private

  def require_pending_session
    return if Current.admin_session&.pending_totp?

    redirect_to new_admin_session_path, alert: "Sign in to continue."
  end
end
```

Create `app/controllers/admin/base_controller.rb`:

```ruby
class Admin::BaseController < Admin::AuthenticationController
  layout "admin"
  before_action :require_admin!

  private

  def require_admin!
    return if Current.admin_user

    if Current.admin_session&.pending_totp?
      redirect_to admin_totp_challenge_path, alert: "Complete verification to continue."
    else
      redirect_to new_admin_session_path, alert: "Sign in to continue."
    end
  end
end
```

- [ ] **Step 5: Implement password, TOTP, recovery, logout, and dashboard controllers**

Create `app/controllers/admin/sessions_controller.rb`:

```ruby
class Admin::SessionsController < Admin::AuthenticationController
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> {
      flash.now[:alert] = "Too many attempts. Try again later."
      render :new, status: :too_many_requests
    }

  def new
    return redirect_to admin_root_path if Current.admin_user
    redirect_to admin_totp_challenge_path if Current.admin_session&.pending_totp?
  end

  def create
    user = AdminUser.authenticate_by(params.expect(admin_login: %i[email password]))

    if user
      start_new_admin_session_for(user, state: :pending_totp)
      redirect_to admin_totp_challenge_path
    else
      flash.now[:alert] = "Email, password, or verification code is invalid."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_admin_session
    redirect_to new_admin_session_path, notice: "Signed out.", status: :see_other
  end
end
```

Create `app/controllers/admin/totp_challenges_controller.rb`:

```ruby
class Admin::TotpChallengesController < Admin::AuthenticationController
  before_action :require_pending_session
  rate_limit to: 5, within: 10.minutes, only: :create,
    by: -> { request.remote_ip },
    with: -> {
      flash.now[:alert] = "Too many attempts. Try again later."
      render :show, status: :too_many_requests
    }

  def show
  end

  def create
    user = Current.admin_session.admin_user

    if user.verify_totp(params.expect(totp: [:code])[:code])
      start_new_admin_session_for(user, state: :verified)
      redirect_to admin_root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Email, password, or verification code is invalid."
      render :show, status: :unprocessable_entity
    end
  end
end
```

Create `app/controllers/admin/recovery_challenges_controller.rb`:

```ruby
class Admin::RecoveryChallengesController < Admin::AuthenticationController
  before_action :require_pending_session
  rate_limit to: 5, within: 10.minutes, only: :create,
    by: -> { request.remote_ip },
    with: -> {
      flash.now[:alert] = "Too many attempts. Try again later."
      render :show, status: :too_many_requests
    }

  def show
  end

  def create
    user = Current.admin_session.admin_user

    if user.consume_recovery_code(params.expect(recovery: [:code])[:code])
      start_new_admin_session_for(user, state: :verified)
      redirect_to admin_root_path, notice: "Signed in. Generate replacement recovery codes after access is restored."
    else
      flash.now[:alert] = "Email, password, or verification code is invalid."
      render :show, status: :unprocessable_entity
    end
  end
end
```

Create `app/controllers/admin/dashboard_controller.rb`:

```ruby
class Admin::DashboardController < Admin::BaseController
  def show
  end
end
```

- [ ] **Step 6: Create the authentication and protected layouts**

Create `app/views/layouts/admin_authentication.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en" data-accent="lime">
  <head>
    <title><%= content_for(:title) || "Portfolio admin" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= theme_bootstrap_script %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
    <main class="mx-auto flex min-h-screen w-full max-w-md items-center px-4 py-10 sm:px-6">
      <section class="w-full" aria-labelledby="admin-auth-heading">
        <% if notice.present? %><p role="status" class="mb-4 rounded border p-3"><%= notice %></p><% end %>
        <% if alert.present? %><p role="alert" class="mb-4 rounded border border-red-600 p-3"><%= alert %></p><% end %>
        <%= yield %>
      </section>
    </main>
  </body>
</html>
```

Create `app/views/layouts/admin.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en" data-accent="lime">
  <head>
    <title><%= content_for(:title) || "Portfolio admin" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= theme_bootstrap_script %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
    <header class="border-b">
      <div class="mx-auto flex w-full max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
        <%= link_to "Portfolio admin", admin_root_path, class: "font-semibold" %>
        <%= button_to "Sign out", admin_session_path, method: :delete,
          class: "min-h-11 rounded border px-4 py-2 font-medium" %>
      </div>
    </header>
    <main class="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6">
      <% if notice.present? %><p role="status" class="mb-4 rounded border p-3"><%= notice %></p><% end %>
      <% if alert.present? %><p role="alert" class="mb-4 rounded border border-red-600 p-3"><%= alert %></p><% end %>
      <%= yield %>
    </main>
  </body>
</html>
```

These layouts intentionally reuse Phase 1's semantic color variables, `:app` stylesheet bundle, and `ThemeHelper#theme_bootstrap_script`. Keep the bootstrap before the stylesheet so the saved theme is applied before paint; do not duplicate or alter the helper's JavaScript.

- [ ] **Step 7: Create complete password, TOTP, recovery, and dashboard views**

Create `app/views/admin/sessions/new.html.erb`:

```erb
<% content_for :title, "Sign in — Portfolio admin" %>
<h1 id="admin-auth-heading" class="text-3xl font-bold">Sign in</h1>
<p class="mt-2 text-sm">Use the owner email and password. A verification code is required next.</p>

<%= form_with url: admin_session_path, scope: :admin_login, class: "mt-8 space-y-5" do |form| %>
  <div>
    <%= form.label :email, class: "block font-medium" %>
    <%= form.email_field :email, required: true, autofocus: true, autocomplete: "username",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2" %>
  </div>
  <div>
    <%= form.label :password, class: "block font-medium" %>
    <%= form.password_field :password, required: true, autocomplete: "current-password",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2" %>
  </div>
  <%= form.submit "Continue", class: "min-h-11 w-full rounded bg-[var(--accent)] px-4 py-2 font-semibold text-[var(--accent-foreground)]" %>
<% end %>

<p class="mt-6"><%= link_to "Forgot password?", new_admin_password_reset_path, class: "underline" %></p>
```

Create `app/views/admin/totp_challenges/show.html.erb`:

```erb
<% content_for :title, "Verify sign in — Portfolio admin" %>
<h1 id="admin-auth-heading" class="text-3xl font-bold">Verification code</h1>
<p class="mt-2 text-sm">Enter the current six-digit code from your authenticator.</p>

<%= form_with url: admin_totp_challenge_path, scope: :totp, class: "mt-8 space-y-5" do |form| %>
  <div>
    <%= form.label :code, "Six-digit code", class: "block font-medium" %>
    <%= form.text_field :code, required: true, autofocus: true, autocomplete: "one-time-code",
      inputmode: "numeric", pattern: "[0-9]{6}", maxlength: 6,
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2 text-lg tracking-widest" %>
  </div>
  <%= form.submit "Verify", class: "min-h-11 w-full rounded bg-[var(--accent)] px-4 py-2 font-semibold text-[var(--accent-foreground)]" %>
<% end %>

<div class="mt-6 flex flex-wrap gap-4">
  <%= link_to "Use a recovery code", admin_recovery_challenge_path, class: "underline" %>
  <%= button_to "Cancel sign in", admin_session_path, method: :delete, class: "underline" %>
</div>
```

Create `app/views/admin/recovery_challenges/show.html.erb`:

```erb
<% content_for :title, "Use recovery code — Portfolio admin" %>
<h1 id="admin-auth-heading" class="text-3xl font-bold">Recovery code</h1>
<p class="mt-2 text-sm">Each recovery code works once. Enter one code saved during owner setup.</p>

<%= form_with url: admin_recovery_challenge_path, scope: :recovery, class: "mt-8 space-y-5" do |form| %>
  <div>
    <%= form.label :code, "Recovery code", class: "block font-medium" %>
    <%= form.text_field :code, required: true, autofocus: true, autocomplete: "off",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2 font-mono uppercase" %>
  </div>
  <%= form.submit "Use recovery code", class: "min-h-11 w-full rounded bg-[var(--accent)] px-4 py-2 font-semibold text-[var(--accent-foreground)]" %>
<% end %>

<p class="mt-6"><%= link_to "Use an authenticator code", admin_totp_challenge_path, class: "underline" %></p>
```

Create `app/views/admin/dashboard/show.html.erb`:

```erb
<% content_for :title, "Dashboard — Portfolio admin" %>
<header>
  <p class="text-sm font-semibold uppercase tracking-wide">Owner dashboard</p>
  <h1 class="mt-2 text-3xl font-bold sm:text-4xl">Dashboard</h1>
</header>
<section class="mt-8 rounded border p-5" aria-labelledby="dashboard-ready-heading">
  <h2 id="dashboard-ready-heading" class="text-xl font-semibold">Secure access is ready</h2>
  <p class="mt-2 max-w-prose">Content management actions are added in Phase 4. This page proves the shared admin authorization boundary.</p>
</section>
```

- [ ] **Step 8: Run request tests and route/security checks**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/authentication_test.rb
mise exec -- ruby bin/rails routes --expanded | grep -E 'admin_(root|session|totp_challenge|recovery_challenge)'
! mise exec -- ruby bin/rails routes | grep -E 'sign.?up|registration|admin_users'
```

Expected: all request tests pass; the listed singular routes exist; the negated registration search exits zero.

- [ ] **Step 9: Commit the interactive authentication flow**

```bash
git add config/routes.rb config/environments/test.rb app/controllers/concerns/admin/authentication.rb app/controllers/admin/authentication_controller.rb app/controllers/admin/base_controller.rb app/controllers/admin/sessions_controller.rb app/controllers/admin/totp_challenges_controller.rb app/controllers/admin/recovery_challenges_controller.rb app/controllers/admin/dashboard_controller.rb app/views/layouts/admin_authentication.html.erb app/views/layouts/admin.html.erb app/views/admin/sessions/new.html.erb app/views/admin/totp_challenges/show.html.erb app/views/admin/recovery_challenges/show.html.erb app/views/admin/dashboard/show.html.erb test/requests/admin/authentication_test.rb
git commit -m "feat: require password and second factor for admin"
```

---

### Task 4: Add generic, expiring password reset

**Files:**

- Modify: `app/models/admin_user.rb`
- Create: `app/controllers/admin/password_resets_controller.rb`
- Create: `app/mailers/admin_password_mailer.rb`
- Create: `app/views/admin/password_resets/new.html.erb`
- Create: `app/views/admin/password_resets/edit.html.erb`
- Create: `app/views/admin_password_mailer/reset.html.erb`
- Create: `app/views/admin_password_mailer/reset.text.erb`
- Modify: `config/environments/development.rb`
- Modify: `config/environments/test.rb`
- Modify: `config/environments/production.rb`
- Create: `test/requests/admin/password_resets_test.rb`
- Create: `test/mailers/admin_password_mailer_test.rb`

**Interfaces:**

- Consumes: singular password-reset routes from Task 3, `AdminUser#password_reset_token`, `AdminUser.find_by_password_reset_token(token)`, Action Mailer, and Active Job.
- Produces: generic reset request behavior, `AdminUser#reset_password(attributes) -> Boolean`, `AdminPasswordMailer#reset(admin_user)`, a token-protected transactional password update, and all-session revocation after reset.

- [ ] **Step 1: Configure absolute mail URLs**

Add these exact lines inside the matching environment configure blocks:

`config/environments/development.rb`:

```ruby
config.action_mailer.default_url_options = { host: "localhost", port: 3000, protocol: "http" }
```

`config/environments/test.rb`:

```ruby
config.action_mailer.default_url_options = { host: "example.com", protocol: "http" }
```

`config/environments/production.rb`:

```ruby
config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST"), protocol: "https" }
```

`APP_HOST` contains only the production hostname, without a scheme or path, and becomes part of the Phase 8 deployment secret/config contract.

- [ ] **Step 2: Write failing reset request and mailer tests**

Create `test/requests/admin/password_resets_test.rb`:

```ruby
require "test_helper"

class Admin::PasswordResetsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @user = admin_users(:owner)
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
  end

  test "known and unknown emails receive the same generic response" do
    assert_enqueued_email_with AdminPasswordMailer, :reset, args: [@user] do
      post admin_password_reset_path, params: { password_reset: { email: @user.email } }
    end
    known = [response.status, response.location, flash[:notice]]

    clear_enqueued_jobs
    post admin_password_reset_path, params: { password_reset: { email: "missing@example.com" } }
    unknown = [response.status, response.location, flash[:notice]]

    assert_equal known, unknown
    assert_equal "If that email is the owner account, a reset link has been sent.", flash[:notice]
    assert_enqueued_emails 0
  end

  test "reset requests are limited to three per IP each hour" do
    3.times do
      post admin_password_reset_path, params: { password_reset: { email: @user.email } }
      assert_redirected_to new_admin_session_path
    end
    assert_enqueued_emails 3

    post admin_password_reset_path, params: { password_reset: { email: @user.email } }
    assert_redirected_to new_admin_session_path
    assert_equal "If that email is the owner account, a reset link has been sent.", flash[:notice]
    assert_enqueued_emails 3
  end

  test "valid reset changes password revokes sessions and invalidates token" do
    session_record = @user.admin_sessions.create!(state: :verified)
    token = @user.password_reset_token

    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: {
        password: "new correct horse battery staple",
        password_confirmation: "new correct horse battery staple"
      }
    }

    assert_redirected_to new_admin_session_path
    assert @user.reload.authenticate("new correct horse battery staple")
    assert_not AdminSession.exists?(session_record.id)
    assert_nil AdminUser.find_by_password_reset_token(token)
  end

  test "reset form URL contains no bearer token" do
    get edit_admin_password_reset_path

    assert_response :success
    assert_select "input[name=token][autocomplete=off]"
    assert_not_includes request.fullpath, "token="
  end

  test "expired token fails with a safe redirect" do
    token = @user.password_reset_token
    travel 31.minutes
    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: { password: "new correct horse battery staple", password_confirmation: "new correct horse battery staple" }
    }

    assert_redirected_to new_admin_password_reset_path
    assert_equal "This reset code is invalid or expired.", flash[:alert]
  end

  test "altered token fails with the same safe redirect" do
    patch admin_password_reset_path, params: {
      token: "#{@user.password_reset_token}altered",
      admin_password_reset: { password: "new correct horse battery staple", password_confirmation: "new correct horse battery staple" }
    }

    assert_redirected_to new_admin_password_reset_path
    assert_equal "This reset code is invalid or expired.", flash[:alert]
  end

  test "password validation preserves the token form without changing password" do
    token = @user.password_reset_token
    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: { password: "short", password_confirmation: "different" }
    }

    assert_response :unprocessable_entity
    assert_select "input[name=token][value=?]", token
    assert @user.reload.authenticate(TEST_PASSWORD)
  end
end
```

Create `test/mailers/admin_password_mailer_test.rb`:

```ruby
require "test_helper"

class AdminPasswordMailerTest < ActionMailer::TestCase
  test "reset addresses only the owner and mints a usable expiring token while rendering" do
    user = admin_users(:owner)
    mail = AdminPasswordMailer.reset(user)
    text_body = mail.text_part.body.decoded
    token = text_body.match(/Enter this one-time reset code:\s*\n([^\s]+)/).captures.first

    assert_equal [user.email], mail.to
    assert_equal [ENV.fetch("MAILER_FROM", "portfolio@example.test")], mail.from
    assert_equal "Reset your portfolio admin password", mail.subject
    assert_match edit_admin_password_reset_url, text_body
    assert_match edit_admin_password_reset_url, mail.html_part.body.decoded
    assert_match token, text_body
    assert_match token, mail.html_part.body.decoded
    assert_equal user, AdminUser.find_by_password_reset_token(token)
    assert_no_match(/token=/, mail.body.encoded)
    assert_no_match TEST_PASSWORD, mail.body.encoded
    assert_no_match user.totp_secret, mail.body.encoded
  end
end
```

- [ ] **Step 3: Run reset tests and verify red**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/password_resets_test.rb test/mailers/admin_password_mailer_test.rb
```

Expected: controller/mailer constant errors.

- [ ] **Step 4: Implement the transactional password reset and its HTTP flow**

Add this public method to `AdminUser` immediately before `#verify_totp`:

```ruby
def reset_password(attributes)
  transaction do
    next false unless update(attributes)

    admin_sessions.delete_all
    true
  end
end
```

Create `app/controllers/admin/password_resets_controller.rb`:

```ruby
class Admin::PasswordResetsController < Admin::AuthenticationController
  GENERIC_NOTICE = "If that email is the owner account, a reset link has been sent."

  rate_limit to: 3, within: 1.hour, only: :create,
    with: -> { redirect_to new_admin_session_path, notice: GENERIC_NOTICE }

  def new
  end

  def create
    email = params.expect(password_reset: [:email])[:email]
    if (user = AdminUser.find_by(email: email))
      AdminPasswordMailer.reset(user).deliver_later
    end

    redirect_to new_admin_session_path, notice: GENERIC_NOTICE
  end

  def edit
    @admin_user = AdminUser.new
  end

  def update
    @token = params[:token].to_s
    return redirect_for_invalid_token unless (@admin_user = reset_user(@token))

    if @admin_user.reset_password(password_params)
      redirect_to new_admin_session_path, notice: "Password reset. Sign in with your new password and verification code."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def reset_user(token)
    AdminUser.find_by_password_reset_token(token)
  end

  def password_params
    params.expect(admin_password_reset: %i[password password_confirmation])
  end

  def redirect_for_invalid_token
    redirect_to new_admin_password_reset_path, alert: "This reset code is invalid or expired."
  end
end
```

The reset token intentionally uses `params[:token]`: a missing token follows the same safe invalid-token redirect as an altered or expired token, while every required structured form payload uses `params.expect`.

- [ ] **Step 5: Implement reset email and forms**

Create `app/mailers/admin_password_mailer.rb`:

```ruby
class AdminPasswordMailer < ApplicationMailer
  def reset(admin_user)
    @admin_user = admin_user
    @token = admin_user.password_reset_token
    @reset_url = edit_admin_password_reset_url
    mail(
      to: admin_user.email,
      from: ENV.fetch("MAILER_FROM", "portfolio@example.test"),
      subject: "Reset your portfolio admin password"
    )
  end
end
```

Create `app/views/admin_password_mailer/reset.text.erb`:

```erb
A password reset was requested for the portfolio admin.

Open this page within 30 minutes:
<%= @reset_url %>

Enter this one-time reset code:
<%= @token %>

If you did not request this, ignore this email. Your password and second factor have not changed.
```

Create `app/views/admin_password_mailer/reset.html.erb`:

```erb
<p>A password reset was requested for the portfolio admin.</p>
<p><%= link_to "Open the password reset page within 30 minutes", @reset_url %></p>
<p>Enter this one-time reset code:</p>
<p><code><%= @token %></code></p>
<p>If you did not request this, ignore this email. Your password and second factor have not changed.</p>
```

Create `app/views/admin/password_resets/new.html.erb`:

```erb
<% content_for :title, "Reset password — Portfolio admin" %>
<h1 id="admin-auth-heading" class="text-3xl font-bold">Reset password</h1>
<p class="mt-2 text-sm">Submit the owner email. The response is the same whether or not it matches the account.</p>

<%= form_with url: admin_password_reset_path, scope: :password_reset, class: "mt-8 space-y-5" do |form| %>
  <div>
    <%= form.label :email, class: "block font-medium" %>
    <%= form.email_field :email, required: true, autofocus: true, autocomplete: "email",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2" %>
  </div>
  <%= form.submit "Send reset link", class: "min-h-11 w-full rounded bg-[var(--accent)] px-4 py-2 font-semibold text-[var(--accent-foreground)]" %>
<% end %>

<p class="mt-6"><%= link_to "Back to sign in", new_admin_session_path, class: "underline" %></p>
```

Create `app/views/admin/password_resets/edit.html.erb`:

```erb
<% content_for :title, "Choose new password — Portfolio admin" %>
<h1 id="admin-auth-heading" class="text-3xl font-bold">Choose a new password</h1>
<p class="mt-2 text-sm">Use at least 14 characters. Existing admin sessions will be signed out.</p>

<% if @admin_user.errors.any? %>
  <div role="alert" class="mt-6 rounded border border-red-600 p-3">
    <p class="font-semibold">Password could not be reset:</p>
    <ul class="mt-2 list-disc pl-5">
      <% @admin_user.errors.full_messages.each do |message| %><li><%= message %></li><% end %>
    </ul>
  </div>
<% end %>

<%= form_with url: admin_password_reset_path, scope: :admin_password_reset, method: :patch, class: "mt-8 space-y-5" do |form| %>
  <div>
    <%= label_tag :token, "Reset code", class: "block font-medium" %>
    <%= text_field_tag :token, @token, required: true, autocomplete: "off",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2 font-mono" %>
  </div>
  <div>
    <%= form.label :password, "New password", class: "block font-medium" %>
    <%= form.password_field :password, required: true, minlength: 14, autocomplete: "new-password",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2" %>
  </div>
  <div>
    <%= form.label :password_confirmation, "Confirm new password", class: "block font-medium" %>
    <%= form.password_field :password_confirmation, required: true, minlength: 14, autocomplete: "new-password",
      class: "mt-2 min-h-11 w-full rounded border bg-transparent px-3 py-2" %>
  </div>
  <%= form.submit "Reset password", class: "min-h-11 w-full rounded bg-[var(--accent)] px-4 py-2 font-semibold text-[var(--accent-foreground)]" %>
<% end %>
```

- [ ] **Step 6: Run reset, mailer, and authentication regression tests**

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/password_resets_test.rb test/mailers/admin_password_mailer_test.rb test/requests/admin/authentication_test.rb
```

Expected: all reset, mailer, authentication, rotation, and throttling tests pass.

- [ ] **Step 7: Commit password reset**

```bash
git add app/models/admin_user.rb app/controllers/admin/password_resets_controller.rb app/mailers/admin_password_mailer.rb app/views/admin/password_resets/new.html.erb app/views/admin/password_resets/edit.html.erb app/views/admin_password_mailer/reset.html.erb app/views/admin_password_mailer/reset.text.erb config/environments/development.rb config/environments/test.rb config/environments/production.rb test/requests/admin/password_resets_test.rb test/mailers/admin_password_mailer_test.rb
git commit -m "feat: add generic expiring admin password reset"
```

---

### Task 5: Add the non-interactive owner creation and credential-rotation task

**Files:**

- Modify: `app/models/admin_user.rb`
- Create: `lib/tasks/admin.rake`
- Create: `test/tasks/admin_create_test.rb`

**Interfaces:**

- Consumes: the `AdminUser` credential/session associations and environment variables.
- Produces: `AdminUser.provision(email:, password:) -> [AdminUser, Array<String>]`, `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails admin:create`, idempotent single-owner creation/reset, enrollment URI, ten plaintext recovery codes, and session revocation.

- [ ] **Step 1: Write failing task tests**

Create `test/tasks/admin_create_test.rb`:

```ruby
require "test_helper"
require "rake"

class AdminCreateTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:create")
    @task = Rake::Task["admin:create"]
    @original_email = ENV["ADMIN_EMAIL"]
    @original_password = ENV["ADMIN_PASSWORD"]
    AdminSession.delete_all
    AdminUser.delete_all
  end

  teardown do
    ENV["ADMIN_EMAIL"] = @original_email
    ENV["ADMIN_PASSWORD"] = @original_password
    @task.reenable
  end

  test "requires both environment variables" do
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")

    error = assert_raises(KeyError) { @task.invoke }
    assert_match "ADMIN_EMAIL", error.message
  end

  test "rejects invalid email and short password without creating an owner" do
    ENV["ADMIN_EMAIL"] = "not-an-email"
    ENV["ADMIN_PASSWORD"] = "deployment correct horse battery"
    error = assert_raises(ArgumentError) { @task.invoke }
    assert_equal "ADMIN_EMAIL must be a valid email address", error.message
    assert_equal 0, AdminUser.count

    @task.reenable
    ENV["ADMIN_EMAIL"] = "owner@example.com"
    ENV["ADMIN_PASSWORD"] = "short"
    error = assert_raises(ArgumentError) { @task.invoke }
    assert_equal "ADMIN_PASSWORD must be at least 14 characters", error.message
    assert_equal 0, AdminUser.count
  end

  test "creates one owner and prints usable enrollment material once" do
    ENV["ADMIN_EMAIL"] = "OWNER@example.com"
    ENV["ADMIN_PASSWORD"] = "deployment correct horse battery"

    output, = capture_io { @task.invoke }
    user = AdminUser.sole
    codes = output.lines.grep(/\A[0-9A-F]{4}(?:-[0-9A-F]{4}){4}\n\z/).map(&:strip)

    assert_equal "owner@example.com", user.email
    assert user.authenticate("deployment correct horse battery")
    assert_match %r{otpauth://totp/}, output
    assert_equal 10, codes.length
    assert user.consume_recovery_code(codes.first)
    assert_not_includes output, ENV.fetch("ADMIN_PASSWORD")
  end

  test "rerun resets credentials without adding an owner and revokes sessions" do
    existing = AdminUser.create!(
      email: "owner@example.com",
      password: TEST_PASSWORD,
      password_confirmation: TEST_PASSWORD,
      totp_secret: TEST_TOTP_SECRET
    )
    session_record = existing.admin_sessions.create!(state: :verified)
    old_secret = existing.totp_secret
    ENV["ADMIN_EMAIL"] = "new-owner@example.com"
    ENV["ADMIN_PASSWORD"] = "replacement correct horse battery"

    capture_io { @task.invoke }
    existing.reload

    assert_equal 1, AdminUser.count
    assert_equal "new-owner@example.com", existing.email
    assert_not_equal old_secret, existing.totp_secret
    assert existing.authenticate("replacement correct horse battery")
    assert_not AdminSession.exists?(session_record.id)
  end
end
```

The test uses `AdminUser.sole`, Rails' native relation method that raises unless exactly one row exists.

- [ ] **Step 2: Run the task test and verify red**

Run:

```bash
mise exec -- ruby bin/rails test test/tasks/admin_create_test.rb
```

Expected: tests fail because the `admin:create` Rake task is undefined.

- [ ] **Step 3: Implement model-owned provisioning and the thin task**

Add `.provision` as the first method inside `AdminUser`'s existing `class << self` block:

```ruby
def provision(email:, password:)
  transaction do
    user = lock.first || new
    user.assign_attributes(
      email: email,
      password: password,
      password_confirmation: password,
      totp_secret: ROTP::Base32.random,
      last_totp_at: nil
    )
    user.save!
    recovery_codes = user.replace_recovery_codes
    user.admin_sessions.delete_all
    [user, recovery_codes]
  end
end
```

Create `lib/tasks/admin.rake`:

```ruby
namespace :admin do
  desc "Create or reset the single admin owner from ADMIN_EMAIL and ADMIN_PASSWORD"
  task create: :environment do
    email = ENV.fetch("ADMIN_EMAIL").strip.downcase
    password = ENV.fetch("ADMIN_PASSWORD")

    raise ArgumentError, "ADMIN_EMAIL must be a valid email address" unless email.match?(URI::MailTo::EMAIL_REGEXP)
    raise ArgumentError, "ADMIN_PASSWORD must be at least 14 characters" if password.length < 14

    user, recovery_codes = AdminUser.provision(email: email, password: password)

    puts "Owner credentials rotated. Save this output now; recovery codes are not recoverable."
    puts "TOTP provisioning URI:"
    puts user.totp_provisioning_uri
    puts "Recovery codes:"
    recovery_codes.each { |code| puts code }
  end
end
```

- [ ] **Step 4: Run tests and exercise the exact operator command in development**

Run:

```bash
mise exec -- ruby bin/rails test test/tasks/admin_create_test.rb
ADMIN_EMAIL=owner@example.test ADMIN_PASSWORD='use-a-password-manager-value' mise exec -- ruby bin/rails admin:create
mise exec -- ruby bin/rails runner 'abort unless AdminUser.count == 1; abort unless AdminSession.count == 0'
```

Expected: four tests pass; the command prints one `otpauth://` URI and ten distinct recovery codes; the runner exits zero. Delete this demonstration owner if it should not remain in the local development database:

```bash
mise exec -- ruby bin/rails runner 'AdminUser.delete_all'
```

- [ ] **Step 5: Commit owner provisioning**

```bash
git add app/models/admin_user.rb lib/tasks/admin.rake test/tasks/admin_create_test.rb
git commit -m "feat: add admin credential provisioning task"
```

---

### Task 6: Prove the browser flow and close the Phase 3 security boundary

**Files:**

- Create: `config/initializers/content_security_policy.rb`
- Modify: `config/application.rb`
- Modify: `config/environments/production.rb`
- Create: `test/requests/admin/security_headers_test.rb`
- Create: `test/system/admin_authentication_test.rb`
- Modify only if the checks expose a defect: Phase 3 files listed above

**Interfaces:**

- Consumes: complete Phase 3 routes, forms, session rotation, TOTP/recovery methods, and protected dashboard.
- Produces: browser-level acceptance evidence for password + second factor, recovery, logout, mobile layout, and generic reset.

- [ ] **Step 1: Add and test CSP plus standard secure headers**

Create `config/initializers/content_security_policy.rb`:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.connect_src :self
    policy.font_src :self, :data
    policy.form_action :self
    policy.frame_ancestors :none
    policy.img_src :self, :data
    policy.object_src :none
    policy.script_src :self
    policy.style_src :self
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
```

Rails already supplies `X-Content-Type-Options: nosniff` and `Referrer-Policy: strict-origin-when-cross-origin`. Add only the missing permission policy and stricter frame rule to `config/application.rb` inside `class Application < Rails::Application`:

```ruby
config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()",
  "X-Frame-Options" => "DENY"
)
```

Ensure `config/environments/production.rb` contains:

```ruby
config.force_ssl = true
```

Create `test/requests/admin/security_headers_test.rb`:

```ruby
require "test_helper"

class Admin::SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "admin authentication responses send CSP and standard security headers" do
    get new_admin_session_path

    assert_response :success
    assert_includes response.headers.fetch("Content-Security-Policy"), "default-src 'self'"
    assert_includes response.headers.fetch("Content-Security-Policy"), "frame-ancestors 'none'"
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_equal "camera=(), microphone=(), geolocation=()", response.headers["Permissions-Policy"]
  end

  test "parameter filtering removes nested authentication secrets" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      totp: { code: "123456" },
      recovery: { code: "AAAA-BBBB-CCCC-DDDD-EEEE" },
      token: "signed-reset-token",
      password: "secret-password"
    )

    assert_equal "[FILTERED]", filtered[:totp]
    assert_equal "[FILTERED]", filtered[:recovery]
    assert_equal "[FILTERED]", filtered[:token]
    assert_equal "[FILTERED]", filtered[:password]
  end
end
```

Run:

```bash
mise exec -- ruby bin/rails test test/requests/admin/security_headers_test.rb
mise exec -- ruby bin/rails test:system test/system/public_shell_test.rb
```

Expected: the header/filter tests pass, and the existing public system suite proves Phase 1's nonce-bearing theme bootstrap and importmap still run under this global policy.

- [ ] **Step 2: Write the end-to-end system test**

Create `test/system/admin_authentication_test.rb`:

```ruby
require "application_system_test_case"

class AdminAuthenticationTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @user = admin_users(:owner)
    @recovery_codes = @user.replace_recovery_codes
  end

  test "owner signs in with password and TOTP then signs out" do
    visit admin_root_path
    assert_current_path new_admin_session_path

    sign_in_owner

    assert_current_path admin_root_path
    assert_text "Secure access is ready"
    click_button "Sign out"

    assert_current_path new_admin_session_path
    visit admin_root_path
    assert_current_path new_admin_session_path
  end

  test "owner uses a recovery code only once" do
    sign_in_password_stage
    click_link "Use a recovery code"
    fill_in "Recovery code", with: @recovery_codes.first
    click_button "Use recovery code"
    assert_current_path admin_root_path

    click_button "Sign out"
    sign_in_password_stage
    click_link "Use a recovery code"
    fill_in "Recovery code", with: @recovery_codes.first
    click_button "Use recovery code"
    assert_text "Email, password, or verification code is invalid."
  end

  test "reset request response stays generic" do
    visit new_admin_password_reset_path
    fill_in "Email", with: @user.email

    perform_enqueued_jobs { click_button "Send reset link" }

    assert_current_path new_admin_session_path
    assert_text "If that email is the owner account, a reset link has been sent."
  end

  test "authentication pages fit a 320 pixel viewport" do
    page.current_window.resize_to(320, 720)
    visit new_admin_session_path

    overflow = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
    assert_equal false, overflow
    assert_button "Continue"
    assert_link "Forgot password?"
  end

  private

  def sign_in_password_stage
    visit new_admin_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: TEST_PASSWORD
    click_button "Continue"
  end
end
```

- [ ] **Step 3: Run the system test and fix only exposed Phase 3 defects**

Run:

```bash
mise exec -- ruby bin/rails test:system test/system/admin_authentication_test.rb
```

Expected: four system tests pass. If Selenium is unavailable, install the browser/driver required by the Phase 1 `ApplicationSystemTestCase`; do not replace this with a JavaScript framework or add an authentication gem.

- [ ] **Step 4: Run the complete Phase 3 automated acceptance suite**

Run:

```bash
mise exec -- ruby bin/rails test test/models/admin_user_test.rb test/models/admin_session_test.rb test/models/current_test.rb test/requests/admin/authentication_test.rb test/requests/admin/password_resets_test.rb test/mailers/admin_password_mailer_test.rb test/tasks/admin_create_test.rb test/requests/admin/security_headers_test.rb
mise exec -- ruby bin/rails test
mise exec -- ruby bin/rails test:system
mise exec -- ruby bin/rails zeitwerk:check
mise exec -- ruby bin/rails routes | grep -E 'admin/(session|totp_challenge|recovery_challenge|password_reset)'
! mise exec -- ruby bin/rails routes | grep -E 'sign.?up|registration|admin_users'
```

Expected: all focused tests, the full unit/request suite, and the full system suite pass; Zeitwerk reports `All is good!`; auth/reset routes exist; no registration route exists.

- [ ] **Step 5: Perform the manual security verification**

Run the app and create a disposable local owner:

```bash
ADMIN_EMAIL=owner@example.test ADMIN_PASSWORD='manual-password-manager-value' mise exec -- ruby bin/rails admin:create
mise exec -- ruby bin/rails server
```

Verify in a private browser window:

1. `/admin` redirects to `/admin/session/new`.
2. A wrong email and wrong password show identical copy and status behavior.
3. Correct password reaches the TOTP page but cannot load the dashboard.
4. Scanning the printed URI signs in; submitting that same six-digit code after logout fails.
5. One printed recovery code signs in once and fails on reuse.
6. Sign out removes access; waiting/testing with time travel proves 10-minute pending and 12-hour verified expiry.
7. Four reset submissions in one hour enqueue no fourth email and show the same generic response.
8. A reset code fails after 30 minutes; a successful reset revokes a previously open session and still requires TOTP.
9. Browser storage shows `admin_session` scoped to `/admin`, `HttpOnly`, `SameSite=Strict`, and `Secure` over HTTPS/production.
10. Password, reset token, TOTP secret/code, and recovery code do not appear in Rails parameter logs or SQLite plaintext columns; the signed session cookie contains only Rails' authenticated representation of the database session ID.
11. At 320 CSS pixels and 200% zoom, every auth action remains visible, keyboard reachable, and free of horizontal overflow.

Stop the server and remove the disposable owner:

```bash
mise exec -- ruby bin/rails runner 'AdminUser.delete_all'
```

- [ ] **Step 6: Commit security hardening/system acceptance and tag the accepted phase**

```bash
git add config/initializers/content_security_policy.rb config/application.rb config/environments/production.rb test/requests/admin/security_headers_test.rb test/system/admin_authentication_test.rb
git commit -m "test: harden and verify admin authentication"
git status --short
git tag -a portfolio-v4-phase-3 -m "Portfolio v4 Phase 3: owner authentication"
```

Expected: `git status --short` is empty before tagging. Create the tag only after every automated command and manual check above succeeds.

## Risks and Rollback

- **Lost encryption keys make the TOTP secret unrecoverable.** Store all three production Active Record Encryption values outside Git before creating the production owner; backup them separately from the server. Recovery is deliberate credential rotation through `admin:create`, not plaintext storage.
- **Clock drift can reject valid TOTP or permit nearby codes.** The fixed window is ±30 seconds and replay state is persisted. Keep server time synchronized; do not widen the window unless production evidence requires it.
- **Reset email can be delayed.** The token is minted when the queued mail renders, so queue wait time does not consume its 30-minute lifetime; delivery delay after rendering does. The owner can use an unused recovery code or rerun `admin:create`; do not extend token lifetime silently.
- **Rate-limit counters share the production Solid Cache SQLite database.** This is acceptable for the one-container v1 topology and survives web-process restarts. Revisit the store only if deployment moves to multiple hosts or measured abuse bypasses limits.
- **A migration rollback deletes credential/session data.** Before production, rollback normally. After owner creation, prefer a corrective migration; rerunning `admin:create` intentionally replaces credentials and revokes sessions.

## Phase 3 Completion Gate

- [ ] Password alone never grants `/admin`; only a live `verified` `AdminSession` makes `Current.admin_user` non-nil.
- [ ] TOTP ciphertext, password digest, recovery digests, and ordinary `AdminSession` records are the only persisted authentication state; cookie integrity comes from Rails' signed cookie jar.
- [ ] TOTP replay, recovery-code replay, tampered cookies, expired sessions, and expired/altered reset tokens fail closed.
- [ ] Session identifiers rotate between password and second-factor stages, and reset/provisioning revoke all sessions.
- [ ] Login, TOTP, recovery, and reset requests hit their exact throttle limits.
- [ ] Login and reset responses do not disclose whether an owner email exists.
- [ ] Queued reset mail contains only the owner GlobalID; no reset bearer is serialized into Solid Queue arguments.
- [ ] Cookies carry the required production flags; state-changing forms retain Rails CSRF protection.
- [ ] `admin:create` creates or resets exactly one owner without prompts and emits enrollment material once.
- [ ] No registration route exists.
- [ ] `mise exec -- ruby bin/rails test`, `mise exec -- ruby bin/rails test:system`, and `mise exec -- ruby bin/rails zeitwerk:check` pass in the agent environment.
