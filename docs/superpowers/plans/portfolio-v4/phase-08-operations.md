# Portfolio v4 Phase 8 Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Do not dispatch subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply Be Vietnam Pro and prepare locally verified development, deployment, backup, restore, and operator documentation without connecting to or changing a real production server.

**Architecture:** Development remains a normal Rails process and gains an optional one-service Compose workflow that runs through Podman or Docker. The repository prepares Kamal configuration for a future one-container Docker deployment and host scripts for encrypted SQLite and Active Storage backups. Phase execution stops at local tests, static checks, configuration parsing, and local Podman builds; every real-host action is an operator-only procedure in `docs/operations.md`.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.3.1, SQLite 3, Tailwind CSS, Propshaft, Be Vietnam Pro, Podman Compose, Docker Compose, Docker, Kamal 2.12.0, kamal-proxy, Ubuntu 24.04 LTS, Bash, systemd, Restic, S3-compatible object storage, curl SMTP

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

## Global Constraints

- Public locales remain exactly `en`, `fr`, and `vi`; English authored content is required and other authored translations are optional.
- Public URLs keep explicit locale prefixes; `/` continues to redirect by locale cookie, supported `Accept-Language`, then `/en`.
- The admin remains English-only, single-owner, and without registration.
- Public and admin CSS remains usable at 320 CSS pixels, 200% zoom, and without hover.
- Initial color mode continues to follow `prefers-color-scheme`; the existing local override and five accent presets remain unchanged.
- Markdown raw HTML stays disabled and rendered output stays sanitized before persistence.
- Draft, scheduled, missing, and unpublished translations never leak through public routes, search, metadata, or sitemap.
- Contact messages commit before email delivery and remain retryable after delivery failure.
- Be Vietnam Pro is self-hosted. Do not add Google Fonts or weaken the same-origin Content Security Policy.
- `docker-compose.yml` is development-only and must work with `podman compose` and `docker compose`.
- Production deployment remains Kamal on Docker. Do not make Kamal depend on a Podman compatibility shim.
- Phase implementation must not contact production or drill hosts, alter DNS, initialize Restic, install systemd units, send production email, run Kamal deployment commands, or create a production acceptance tag.
- Remote commands appear only inside operator documentation and remain manual after phase implementation.
- Production remains one application container on one small Ubuntu server. Do not add Redis, a separate API, SPA, CMS, search service, CDN, or observability platform.
- `/var/lib/portfolio/storage` is the sole production application bind and is owned by numeric UID/GID `1000:1000`.
- Only `production.sqlite3` and `active_storage/` are backed up. Queue, cache, and cable databases are recreated and never restored.
- Restic keeps 7 daily, 4 weekly, and 6 monthly restore points. Full repository data verification runs during initial acceptance and quarterly drills, not after every nightly backup.
- Recovery targets are RPO at most 24 hours and RTO at most 2 hours.
- Rails master key, encryption keys, SMTP credentials, Restic password, and S3 credentials stay outside Git.
- Preserve the existing `SECRET_KEY_BASE_DUMMY` production boot path so asset precompilation does not require runtime secrets.
- Use existing Rails defaults and installed dependencies before adding code or gems.
- Use Minitest and the smallest runnable shell checks that protect operational behavior.

## Preconditions

- Phases 1–7 are accepted and `git status --short` is empty.
- `ruby --version` reports Ruby 4.0.6 and `bin/rails --version` reports Rails 8.1.3.1.
- `bundle exec kamal version` reports 2.12.0.
- The local development machine has Podman 5.8+ and an external Compose provider.
- No production host, production DNS record, S3 repository, SMTP account, or production secret is required to implement this phase.
- Local Kamal parsing uses documentation-only addresses and dummy values; local checks must not resolve or connect to them.
- The future operator workstation uses Docker and Docker Compose. The future production and drill hosts are AMD64 Ubuntu 24.04 machines.
- Backup and restore commands are designed to run as root on that future Docker host, but are not run there during this phase.

## File Map

| Path                                                | Action  | Responsibility                                                                                                  |
| --------------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------- |
| `public/fonts/BeVietnamPro-Variable.ttf`                | Create  | Self-host normal Be Vietnam Pro weights 100–900.                                                                |
| `public/fonts/BeVietnamPro-Italic-Variable.ttf` | Create  | Self-host italic Be Vietnam Pro weights 100–900.                                                                |
| `vendor/fonts/be-vietnam-pro/OFL.txt`               | Create  | Preserve the font license.                                                                                      |
| `app/assets/tailwind/application.css`               | Modify  | Declare the font faces and apply them through existing font tokens.                                             |
| `test/config/font_assets_test.rb`                   | Create  | Protect the font files and CSS contract.                                                                        |
| `Dockerfile.dev`                                    | Create  | Build the development image without changing the production image.                                              |
| `docker-compose.yml`                                | Create  | Run Rails and Tailwind in one portable development service.                                                     |
| `Procfile.dev`                                      | Modify  | Keep the Tailwind watcher alive in non-TTY detached containers via `watch[always]`.                             |
| `config/storage.yml`                                | Modify  | Isolate production Active Storage under `storage/active_storage`.                                               |
| `config/environments/production.rb`                 | Modify  | Complete TLS, local uploads, SMTP, stdout logging, and Solid Queue settings while preserving dummy-secret boot. |
| `test/controllers/health_check_test.rb`             | Create  | Protect the `/up` deployment contract.                                                                          |
| `test/config/production_boot_test.rb`               | Modify  | Prove asset builds need no runtime SMTP values and real boots reject missing SMTP values.                       |
| `config/database.yml`                               | Verify  | Keep primary, queue, cache, and cable SQLite files distinct under `storage/`.                                   |
| `config/puma.rb`                                    | Verify  | Keep Solid Queue in Puma behind `SOLID_QUEUE_IN_PUMA`.                                                          |
| `config/routes.rb`                                  | Verify  | Keep the Rails `/up` health endpoint.                                                                           |
| `Dockerfile`                                        | Verify  | Keep the working production image, build-time fallback, Thruster command, and UID/GID 1000.                     |
| `.dockerignore`                                     | Verify  | Keep data, secrets, and local state outside image contexts.                                                     |
| `config/deploy.yml`                                 | Replace | Configure one-host Kamal deployment with TLS and the persistent bind.                                           |
| `.kamal/secrets`                                    | Replace | Resolve production secrets from local environment without values in Git.                                        |
| `test/operations/sqlite_backup_test.sh`             | Create  | Prove the exact SQLite online-backup command against a WAL database.                                            |
| `bin/backup`                                        | Create  | Pause, snapshot, resume, upload, retain, verify, and alert.                                                     |
| `ops/systemd/portfolio-backup.service`              | Create  | Run the host backup command as root.                                                                            |
| `ops/systemd/portfolio-backup.timer`                | Create  | Trigger one persistent nightly backup.                                                                          |
| `bin/restore`                                       | Create  | Restore one explicit snapshot with checksums, integrity checks, rollback data, and safe failure state.          |
| `docs/operations.md`                                | Create  | Document provisioning, deployment, backup, restore, failure response, and drills.                               |
| `README.md`                                         | Replace | Document native development, Podman/Docker Compose development, tests, and deployment.                          |

## Manual Operator Environment Contract

These values are documented and wired into configuration during implementation, but real values are neither required nor used by the phase executor.

### Kamal deployment workstation

| Variable                                       | Secret | Meaning                                                         |
| ---------------------------------------------- | ------ | --------------------------------------------------------------- |
| `DEPLOY_HOST`                                  | No     | Production host IP address or SSH-resolvable name.              |
| `APP_HOST`                                     | No     | Production HTTPS DNS name without scheme, port, slash, or path. |
| `RAILS_MASTER_KEY`                             | Yes    | Exact content of `config/master.key`.                           |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`         | Yes    | Production Active Record encryption primary key.                |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`   | Yes    | Production deterministic encryption key.                        |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Yes    | Production encryption derivation salt.                          |
| `SMTP_ADDRESS`                                 | No     | SMTP provider DNS name.                                         |
| `SMTP_PORT`                                    | No     | SMTP submission port; use `587` for STARTTLS.                   |
| `SMTP_DOMAIN`                                  | No     | EHLO domain controlled by the owner.                            |
| `SMTP_USERNAME`                                | Yes    | SMTP submission username.                                       |
| `SMTP_PASSWORD`                                | Yes    | SMTP submission password.                                       |
| `MAILER_FROM`                                  | No     | Verified sender address.                                        |
| `DRILL_HOST`                                   | No     | Disposable restore-drill host.                                  |
| `DRILL_APP_HOST`                               | No     | Restore-drill DNS name.                                         |

### Backup and restore host

`/etc/portfolio/backup.env` is root-owned mode `0600` and contains shell-quoted assignments for:

| Variable                | Secret           | Meaning                                     |
| ----------------------- | ---------------- | ------------------------------------------- |
| `RESTIC_REPOSITORY`     | No               | S3 repository URL ending in `/portfolio`.   |
| `RESTIC_PASSWORD_FILE`  | Yes by reference | Always `/etc/portfolio/restic-password`.    |
| `AWS_ACCESS_KEY_ID`     | Yes              | S3 key restricted to the repository prefix. |
| `AWS_SECRET_ACCESS_KEY` | Yes              | Matching S3 secret key.                     |
| `AWS_DEFAULT_REGION`    | No               | Provider region.                            |
| `OPS_SMTP_URL`          | No               | Complete curl SMTP submission URL.          |
| `OPS_SMTP_USERNAME`     | Yes              | Operational SMTP username.                  |
| `OPS_SMTP_PASSWORD`     | Yes              | Operational SMTP password.                  |
| `OPS_EMAIL_FROM`        | No               | Verified operational sender.                |
| `OPS_EMAIL_TO`          | Yes              | Owner alert address.                        |

`/etc/portfolio/restic-password` is a separately generated, root-owned mode `0600` file. The S3 policy permits list/get/put/delete only for the selected repository prefix.

---

### Task 1: Self-host Be Vietnam Pro

**Files:**

- Create: `public/fonts/BeVietnamPro-Variable.ttf`
- Create: `public/fonts/BeVietnamPro-Italic-Variable.ttf`
- Create: `vendor/fonts/be-vietnam-pro/OFL.txt`
- Modify: `app/assets/tailwind/application.css`
- Create: `test/config/font_assets_test.rb`

**Interfaces:**

- Consumes: Propshaft's existing asset path and the `--font-display` and `--font-body` CSS variables.
- Produces: same-origin Be Vietnam Pro normal and italic faces for weights 100–900 across public and admin layouts.

- [ ] **Step 1: Write the failing font contract test**

```ruby
# test/config/font_assets_test.rb
require "test_helper"

class FontAssetsTest < ActiveSupport::TestCase
  test "self-hosts and applies Be Vietnam Pro" do
    normal_font = Rails.root.join("public/fonts/BeVietnamPro-Variable.ttf")
    italic_font = Rails.root.join("public/fonts/BeVietnamPro-Italic-Variable.ttf")
    license = Rails.root.join("vendor/fonts/be-vietnam-pro/OFL.txt")
    stylesheet = Rails.root.join("app/assets/tailwind/application.css").read

    assert File.exist?(normal_font), "missing #{normal_font}"
    assert File.exist?(italic_font), "missing #{italic_font}"
    assert File.exist?(license), "missing #{license}"
    assert_includes stylesheet, 'font-family: "Be Vietnam Pro"'
    assert_includes stylesheet, 'url("/fonts/BeVietnamPro-Variable.ttf")'
    assert_includes stylesheet, 'url("/fonts/BeVietnamPro-Italic-Variable.ttf")'
    assert_includes stylesheet, '--font-body: "Be Vietnam Pro"'
    assert_includes stylesheet, '--font-display: "Be Vietnam Pro"'
  end
end
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bin/rails test test/config/font_assets_test.rb
```

Expected: failure because the font files and declarations do not exist.

- [ ] **Step 3: Download the exact upstream font files and license**

```bash
install -d public/fonts vendor/fonts/be-vietnam-pro
curl --fail --location --silent --show-error \
  'https://raw.githubusercontent.com/bettergui/BeVietnamPro/main/fonts/variable/BeVietnamPro%5Bwght%5D.ttf' \
  --output public/fonts/BeVietnamPro-Variable.ttf
curl --fail --location --silent --show-error \
  'https://raw.githubusercontent.com/bettergui/BeVietnamPro/main/fonts/variable/BeVietnamPro-Italic%5Bwght%5D.ttf' \
  --output public/fonts/BeVietnamPro-Italic-Variable.ttf
curl --fail --location --silent --show-error \
  'https://raw.githubusercontent.com/bettergui/BeVietnamPro/main/OFL.txt' \
  --output vendor/fonts/be-vietnam-pro/OFL.txt
shasum -a 256 \
  public/fonts/BeVietnamPro-Variable.ttf \
  public/fonts/BeVietnamPro-Italic-Variable.ttf \
  vendor/fonts/be-vietnam-pro/OFL.txt
```

Expected hashes:

```text
2e7f074803b2252224a55ebc3112d19e2e844b5edee4dcf1e91e254f78e69f4c  public/fonts/BeVietnamPro-Variable.ttf
c82ce3bb59565e30e4e9699a0e56164e939c6cd976f65c16b43f15e210a6090e  public/fonts/BeVietnamPro-Italic-Variable.ttf
6b7f8f73609a25ea78c891e34cf37b06f8a676b7ea986e941e43b009110f2a85  vendor/fonts/be-vietnam-pro/OFL.txt
```

If upstream changes a hash, inspect the upstream commit and license before accepting the new file. Do not silently update expected hashes.

- [ ] **Step 4: Declare and apply the font**

Immediately after `@import "tailwindcss";` in `app/assets/tailwind/application.css`, add:

```css
@font-face {
  font-family: "Be Vietnam Pro";
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("/fonts/BeVietnamPro-Variable.ttf") format("truetype");
}

@font-face {
  font-family: "Be Vietnam Pro";
  font-style: italic;
  font-weight: 100 900;
  font-display: swap;
  src: url("/fonts/BeVietnamPro-Italic-Variable.ttf") format("truetype");
}
```

Replace both existing system-only font variables with:

```css
--font-display: "Be Vietnam Pro", ui-sans-serif, system-ui, sans-serif;
--font-body: "Be Vietnam Pro", ui-sans-serif, system-ui, sans-serif;
```

Do not add remote stylesheet tags or CSP hosts.

- [ ] **Step 5: Verify tests and production asset compilation**

```bash
bin/rails test test/config/font_assets_test.rb
bin/rails tailwindcss:build
curl --fail --silent --show-error --include http://127.0.0.1:3000/fonts/BeVietnamPro-Variable.ttf | head -1
curl --fail --silent --show-error --include http://127.0.0.1:3000/fonts/BeVietnamPro-Italic-Variable.ttf | head -1
```

Expected: the test passes, the Tailwind build exits 0, and both `/fonts/` URLs return HTTP 200. Static `public/` files are served unchanged in every environment, so no production asset compilation gate is needed for the fonts. No production runtime variables are required.

- [ ] **Step 6: Check rendered typography**

Run `bin/dev`, open English, French, Vietnamese, and admin pages, and confirm in browser developer tools that body and display text resolve to `Be Vietnam Pro`. At 320 CSS pixels and 200% zoom, confirm headings do not clip or create horizontal scrolling.

- [ ] **Step 7: Commit typography**

```bash
git add public/fonts vendor/fonts/be-vietnam-pro app/assets/tailwind/application.css test/config/font_assets_test.rb
git commit -m "style: use Be Vietnam Pro"
```

---

### Task 2: Add portable development Compose

**Files:**

- Create: `Dockerfile.dev`
- Create: `docker-compose.yml`
- Modify: `Procfile.dev`

**Interfaces:**

- Consumes: `Gemfile.lock`, `bin/dev`, `Procfile.dev`, and the existing development SQLite configuration. The `css` entry in `Procfile.dev` runs `bin/rails 'tailwindcss:watch[always]'` so the watcher polls file changes instead of exiting when stdin closes in detached containers.
- Produces: one `web` development service at `http://localhost:3000`, usable through Podman Compose or Docker Compose.

- [ ] **Step 1: Create the development image**

```dockerfile
# Dockerfile.dev
FROM docker.io/library/ruby:4.0.6-slim

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libvips \
      libyaml-dev \
      pkg-config \
      sqlite3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV BUNDLE_PATH="/usr/local/bundle"

COPY Gemfile Gemfile.lock ./
RUN bundle install && gem install foreman --version 0.90.0 --no-document

COPY . .

EXPOSE 3000
CMD ["bin/dev"]
```

This image is development-only. Do not add development packages to the production `Dockerfile`.

- [ ] **Step 2: Create the Compose application**
```yaml
# docker-compose.yml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: ["sh", "-c", "bin/rails db:prepare && exec bin/dev"]
    environment:
      BINDING: 0.0.0.0
      PORT: "3000"
    ports:
      - "3000:3000"
    volumes:
      - .:/rails
      - portfolio_builds:/rails/app/assets/builds
      - portfolio_storage:/rails/storage
      - portfolio_tmp:/rails/tmp
    stop_grace_period: 10s

volumes:
  portfolio_builds:
  portfolio_storage:
  portfolio_tmp:
```

Do not add a database service; development uses SQLite.

- [ ] **Step 3: Validate and run with Podman on this machine**

```bash
podman machine start
podman compose config
podman compose build
podman compose up --detach
for attempt in $(seq 1 30); do
  curl --fail --silent http://127.0.0.1:3000/en >/dev/null && break
  sleep 1
done
curl --fail --silent --show-error --include http://127.0.0.1:3000/up
podman compose exec web bin/rails test test/config/font_assets_test.rb
podman compose down
```

Expected: Compose configuration and build succeed, `/up` returns HTTP 200, and the focused test passes. The warning that `podman compose` delegates to an external provider is expected.

The operator later runs the equivalent `docker compose` commands documented in `README.md`; they are not part of phase execution.

- [ ] **Step 4: Commit containerized development**

```bash
git add Dockerfile.dev docker-compose.yml
git commit -m "chore: add compose development environment"
```

---

### Task 3: Complete the production runtime contract

**Files:**

- Create: `test/controllers/health_check_test.rb`
- Modify: `test/config/production_boot_test.rb`
- Modify: `config/storage.yml`
- Modify: `config/environments/production.rb`
- Verify: `config/database.yml`
- Verify: `config/puma.rb`
- Verify: `config/routes.rb`

**Interfaces:**

- Consumes: existing multi-database configuration, Solid Queue installation, mailers, and build-time dummy-secret behavior.
- Produces: `/up`, `/rails/storage/production.sqlite3`, `/rails/storage/active_storage`, SMTP delivery, HTTPS assumptions, and in-Puma Solid Queue.

- [ ] **Step 1: Add health and SMTP boot contracts**

```ruby
# test/controllers/health_check_test.rb
require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "GET /up reports a booted application" do
    get "/up"

    assert_response :success
    assert_equal "text/html", response.media_type
  end
end
```

Replace `test/config/production_boot_test.rb` with:

```ruby
require "test_helper"
require "open3"

class ProductionBootTest < ActiveSupport::TestCase
  ENCRYPTION_KEYS = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ]
  SMTP_SETTINGS = %w[
    SMTP_ADDRESS
    SMTP_PORT
    SMTP_DOMAIN
    SMTP_USERNAME
    SMTP_PASSWORD
  ]

  test "asset build boot does not require runtime environment variables" do
    environment = {
      "SECRET_KEY_BASE_DUMMY" => "1",
      "APP_HOST" => nil,
      **SMTP_SETTINGS.index_with(nil)
    }
    _, error, status = production_boot(environment)

    assert_predicate status, :success?, error
  end

  test "runtime boot requires production encryption keys" do
    _, error, status = production_boot

    assert_not_predicate status, :success?
    assert_includes error, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
  end

  test "runtime boot requires SMTP settings" do
    environment = {
      **ENCRYPTION_KEYS.index_with { SecureRandom.base64(32) },
      "SMTP_ADDRESS" => nil
    }
    _, error, status = production_boot(environment)

    assert_not_predicate status, :success?
    assert_includes error, "SMTP_ADDRESS"
  end

  private

  def production_boot(environment = {})
    environment = {
      "RAILS_ENV" => "production",
      "APP_HOST" => "portfolio.invalid",
      "SECRET_KEY_BASE_DUMMY" => nil,
      "SMTP_ADDRESS" => "localhost",
      "SMTP_PORT" => "587",
      "SMTP_DOMAIN" => "portfolio.invalid",
      "SMTP_USERNAME" => "test",
      "SMTP_PASSWORD" => "test",
      **ENCRYPTION_KEYS.index_with(nil),
      **environment
    }

    Open3.capture3(environment, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", "true")
  end
end
```

- [ ] **Step 2: Run the focused tests and verify the new SMTP contract fails**

```bash
bin/rails test test/controllers/health_check_test.rb test/config/production_boot_test.rb
```

Expected: health and the existing boot contracts pass; `runtime boot requires SMTP settings` fails because production does not yet require SMTP.

- [ ] **Step 3: Add the isolated production storage service**

Append to `config/storage.yml`:

```yaml
production:
  service: Disk
  root: <%= Rails.root.join("storage/active_storage") %>
```

Keep `test` and `local` unchanged.

- [ ] **Step 4: Complete production settings without breaking asset builds**

In `config/environments/production.rb`:

1. Change `config.active_storage.service = :local` to:

```ruby
config.active_storage.service = :production
```

2. Enable the SSL proxy assumption and keep forced SSL:

```ruby
config.assume_ssl = true
config.force_ssl = true
config.ssl_options = { hsts: { subdomains: false } }
```

3. Keep the existing `mailer_host` fallback exactly:

```ruby
mailer_host = if ENV["SECRET_KEY_BASE_DUMMY"].present?
  ENV.fetch("APP_HOST", "portfolio.invalid")
else
  ENV.fetch("APP_HOST")
end
config.action_mailer.default_url_options = { host: mailer_host, protocol: "https" }
```

4. Add the delivery settings immediately after that block, guarded only for the asset-build boot:

```ruby
unless ENV["SECRET_KEY_BASE_DUMMY"].present?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: Integer(ENV.fetch("SMTP_PORT")),
    domain: ENV.fetch("SMTP_DOMAIN"),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }
end
```

Keep the existing stdout logger, health-check silence, Solid Cache, Solid Queue adapter, and `config.solid_queue.connects_to` settings.

- [ ] **Step 5: Verify existing database, Puma, route, and sender contracts**

```bash
grep -F 'database: storage/production.sqlite3' config/database.yml
grep -F 'database: storage/production_queue.sqlite3' config/database.yml
grep -F 'database: storage/production_cache.sqlite3' config/database.yml
grep -F 'database: storage/production_cable.sqlite3' config/database.yml
grep -F 'plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]' config/puma.rb
grep -F 'get "up" => "rails/health#show"' config/routes.rb
grep -F 'ENV.fetch("MAILER_FROM", "portfolio@example.test")' app/mailers/admin_password_mailer.rb app/mailers/contact_mailer.rb
```

Expected: each command finds the existing contract exactly. Do not rewrite these files when the checks pass.

- [ ] **Step 6: Verify production configuration and all accepted behavior**

```bash
bin/rails test test/controllers/health_check_test.rb test/config/production_boot_test.rb
RAILS_ENV=production \
APP_HOST=portfolio.invalid \
SMTP_ADDRESS=localhost SMTP_PORT=587 SMTP_DOMAIN=portfolio.invalid \
SMTP_USERNAME=test SMTP_PASSWORD=test \
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="$(openssl rand -base64 32)" \
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="$(openssl rand -base64 32)" \
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="$(openssl rand -base64 32)" \
RAILS_MASTER_KEY="$(cat config/master.key)" \
bin/rails runner 'puts [ActiveRecord::Base.configurations.configs_for(env_name: "production").map(&:database), Rails.application.config.active_storage.service].inspect'
bin/rails test
bin/rails test:system
```

Expected production output:

```text
[["storage/production.sqlite3", "storage/production_cache.sqlite3", "storage/production_queue.sqlite3", "storage/production_cable.sqlite3"], :production]
```

Both full suites exit 0.

- [ ] **Step 7: Commit the runtime contract**

```bash
git add test/controllers/health_check_test.rb test/config/production_boot_test.rb config/storage.yml config/environments/production.rb
git commit -m "chore: complete production runtime contract"
```

---

### Task 4: Prepare the one-host Kamal deployment

**Files:**

- Replace: `config/deploy.yml`
- Replace: `.kamal/secrets`
- Verify: `Dockerfile`
- Verify: `.dockerignore`

**Interfaces:**

- Consumes: Task 3's health, storage, SMTP, and queue contracts.
- Produces: locally parsed Kamal files that will later create one `portfolio-web-*` container with automatic TLS and `/var/lib/portfolio/storage:/rails/storage` when an operator deploys manually.

- [ ] **Step 1: Write the Kamal configuration**

```yaml
# config/deploy.yml
service: portfolio
image: portfolio

servers:
  web:
    - <%= ENV.fetch("DEPLOY_HOST") %>

proxy:
  ssl: true
  host: <%= ENV.fetch("APP_HOST") %>
  app_port: 80
  healthcheck:
    interval: 5
    path: /up
    timeout: 5

registry:
  server: localhost:5555

ssh:
  user: deploy

volumes:
  - /var/lib/portfolio/storage:/rails/storage

asset_path: /rails/public/assets

boot:
  limit: 1
  wait: 2

builder:
  arch: amd64

logging:
  driver: local
  options:
    max-size: 10m
    max-file: 5

env:
  clear:
    APP_HOST: <%= ENV.fetch("APP_HOST") %>
    SMTP_ADDRESS: <%= ENV.fetch("SMTP_ADDRESS") %>
    SMTP_PORT: <%= ENV.fetch("SMTP_PORT") %>
    SMTP_DOMAIN: <%= ENV.fetch("SMTP_DOMAIN") %>
    MAILER_FROM: <%= ENV.fetch("MAILER_FROM") %>
    SOLID_QUEUE_IN_PUMA: "true"
    RAILS_LOG_LEVEL: info
  secret:
    - RAILS_MASTER_KEY
    - ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    - ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    - ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
    - SMTP_USERNAME
    - SMTP_PASSWORD

aliases:
  console: app exec --interactive --reuse "bin/rails console"
  shell: app exec --interactive --reuse "bash"
  logs: app logs -f
```

The localhost registry is Kamal's temporary local Docker registry. Do not add a permanent registry service.

- [ ] **Step 2: Resolve Kamal secrets from the deployment shell**

```bash
# .kamal/secrets
RAILS_MASTER_KEY=${RAILS_MASTER_KEY:-$(cat config/master.key)}
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
SMTP_USERNAME=$SMTP_USERNAME
SMTP_PASSWORD=$SMTP_PASSWORD
```

Verify references without printing secret values:

```bash
grep -Fqx 'RAILS_MASTER_KEY=${RAILS_MASTER_KEY:-$(cat config/master.key)}' .kamal/secrets
grep -Fqx 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' .kamal/secrets
grep -Fqx 'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY' .kamal/secrets
grep -Fqx 'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT' .kamal/secrets
grep -Fqx 'SMTP_USERNAME=$SMTP_USERNAME' .kamal/secrets
grep -Fqx 'SMTP_PASSWORD=$SMTP_PASSWORD' .kamal/secrets
```

Expected: all commands are silent and exit 0.

- [ ] **Step 3: Verify the production image and ignore rules instead of replacing them**

```bash
grep -F 'ARG RUBY_VERSION=4.0.6' Dockerfile
grep -F 'USER 1000:1000' Dockerfile
grep -F 'ENTRYPOINT ["/rails/bin/docker-entrypoint"]' Dockerfile
grep -F 'CMD ["./bin/thrust", "./bin/rails", "server"]' Dockerfile
grep -F '/config/master.key' .dockerignore
grep -F '/storage/*' .dockerignore
grep -F '/.kamal' .dockerignore
bin/rails test test/config/production_boot_test.rb
```

Expected: every check passes. Preserve the existing Dockerfile's jemalloc setup, `vendor/` copy, serial Bootsnap precompile, and dummy-secret asset build.

- [ ] **Step 4: Parse Kamal configuration locally with non-routable dummy values**

```bash
DEPLOY_HOST=192.0.2.10 \
APP_HOST=portfolio.invalid \
RAILS_MASTER_KEY=dummy-master-key \
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=dummy-primary-key \
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=dummy-deterministic-key \
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=dummy-derivation-salt \
SMTP_ADDRESS=smtp.invalid SMTP_PORT=587 SMTP_DOMAIN=portfolio.invalid \
SMTP_USERNAME=dummy-smtp-user SMTP_PASSWORD=dummy-smtp-password \
MAILER_FROM=owner@portfolio.invalid \
bin/kamal config >/dev/null
```

Expected: Kamal accepts the complete configuration and exits 0. `192.0.2.10` and `.invalid` are documentation-only values; this command must not make a network connection.

- [ ] **Step 5: Build and inspect the production image locally with Podman**

```bash
podman build --platform linux/amd64 -t portfolio:phase-8 .
podman image inspect portfolio:phase-8 \
  --format '{{.Config.User}} {{json .Config.ExposedPorts}} {{json .Config.Cmd}}'
```

Expected output contains numeric user `1000:1000`, exposed port `80/tcp`, and command `./bin/thrust ./bin/rails server`. Do not push the image or run Kamal.

- [ ] **Step 6: Commit prepared deployment configuration**

```bash
git add config/deploy.yml .kamal/secrets
git commit -m "chore: prepare kamal deployment"
```

Host provisioning, DNS checks, `kamal setup`, deployment, SMTP verification, persistence checks, and rollback remain operator-only procedures in `docs/operations.md`.

---

### Task 5: Prepare and locally verify encrypted backup automation

**Files:**

- Create: `test/operations/sqlite_backup_test.sh`
- Create: `bin/backup`
- Create: `ops/systemd/portfolio-backup.service`
- Create: `ops/systemd/portfolio-backup.timer`

**Interfaces:**

- Consumes: the sole running Docker container, `/var/lib/portfolio/storage`, `/etc/portfolio/backup.env`, and `/etc/portfolio/restic-password`.
- Produces: locally checked scripts that will create Restic snapshots tagged `portfolio` and `nightly`, retry unpause, enforce 7/4/6 retention, and report failure when the operator installs them.

- [ ] **Step 1: Add a failing executable SQLite backup proof**

```bash
#!/usr/bin/env bash
# test/operations/sqlite_backup_test.sh
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
source_db="$tmpdir/production.sqlite3"
snapshot_db="$tmpdir/snapshot.sqlite3"

sqlite3 "$source_db" <<'SQL'
PRAGMA journal_mode=WAL;
CREATE TABLE records(id INTEGER PRIMARY KEY, value TEXT NOT NULL);
INSERT INTO records(value) VALUES ('before-backup');
SQL

sqlite3 "$source_db" ".timeout 5000" ".backup '$snapshot_db'"

test "$(sqlite3 "$snapshot_db" 'PRAGMA integrity_check;')" = ok
test "$(sqlite3 "$snapshot_db" 'SELECT value FROM records;')" = before-backup
printf 'SQLite online backup verified\n'
```

```bash
chmod 0755 test/operations/sqlite_backup_test.sh
test/operations/sqlite_backup_test.sh
```

Expected before SQLite is available: nonzero with `sqlite3: command not found`. Expected on the supported development and host environments: `SQLite online backup verified`.

- [ ] **Step 2: Create the host backup command**

```bash
#!/usr/bin/env bash
# bin/backup
set -euo pipefail
umask 077

readonly DATA_DIR=/var/lib/portfolio/storage
readonly PRIMARY_DB="$DATA_DIR/production.sqlite3"
readonly ASSET_DIR="$DATA_DIR/active_storage"
readonly WORK_ROOT=/var/lib/portfolio/backup-work
readonly ENV_FILE=/etc/portfolio/backup.env
readonly LOCK_FILE=/run/lock/portfolio-backup.lock

PAUSED=0
APP_CONTAINER=""
STAGE=""
SNAPSHOT_CREATED=0

notify_failure() {
  local message=$1
  logger -t portfolio-backup -- "$message" || true
  if [[ -n "${OPS_SMTP_URL:-}" && -n "${OPS_SMTP_USERNAME:-}" && -n "${OPS_SMTP_PASSWORD:-}" && -n "${OPS_EMAIL_FROM:-}" && -n "${OPS_EMAIL_TO:-}" ]]; then
    printf 'From: %s\r\nTo: %s\r\nSubject: Portfolio backup failed on %s\r\n\r\n%s\r\n' \
      "$OPS_EMAIL_FROM" "$OPS_EMAIL_TO" "$(hostname -f)" "$message" |
      curl --silent --show-error --fail --ssl-reqd \
        --url "$OPS_SMTP_URL" \
        --user "$OPS_SMTP_USERNAME:$OPS_SMTP_PASSWORD" \
        --mail-from "$OPS_EMAIL_FROM" \
        --mail-rcpt "$OPS_EMAIL_TO" \
        --upload-file - >/dev/null || logger -t portfolio-backup -- "SMTP failure alert could not be sent" || true
  fi
}

resume_app() {
  [[ "$PAUSED" == 1 && -n "$APP_CONTAINER" ]] || return 0

  for _attempt in 1 2 3; do
    if docker unpause "$APP_CONTAINER" >/dev/null 2>&1; then
      PAUSED=0
      return 0
    fi
    sleep 1
  done

  return 1
}

cleanup() {
  local status=$?
  local resumed=1
  trap - EXIT
  set +e

  resume_app || resumed=0
  [[ -z "$STAGE" ]] || rm -rf -- "$STAGE"

  if [[ "$status" -ne 0 || "$resumed" -eq 0 ]]; then
    notify_failure "bin/backup exited=$status resumed=$resumed snapshot_created=$SNAPSHOT_CREATED; inspect Docker state and backup logs"
  fi

  if [[ "$status" -eq 0 && "$resumed" -eq 0 ]]; then
    status=1
  fi
  exit "$status"
}

require_command() {
  command -v "$1" >/dev/null || { echo "missing command: $1" >&2; return 1; }
}

require_env() {
  [[ -n "${!1:-}" ]] || { echo "missing environment variable: $1" >&2; return 1; }
}

trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo "bin/backup must run as root" >&2; exit 1; }
[[ -r "$ENV_FILE" ]] || { echo "cannot read $ENV_FILE" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for command_name in curl docker flock logger restic rsync sha256sum sqlite3; do
  require_command "$command_name"
done
for variable_name in RESTIC_REPOSITORY RESTIC_PASSWORD_FILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION OPS_SMTP_URL OPS_SMTP_USERNAME OPS_SMTP_PASSWORD OPS_EMAIL_FROM OPS_EMAIL_TO; do
  require_env "$variable_name"
done
[[ -r "$RESTIC_PASSWORD_FILE" ]] || { echo "cannot read RESTIC_PASSWORD_FILE" >&2; exit 1; }
[[ -f "$PRIMARY_DB" ]] || { echo "missing primary database: $PRIMARY_DB" >&2; exit 1; }

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another backup or restore is running" >&2; exit 75; }
install -d -o 1000 -g 1000 -m 0750 "$ASSET_DIR"

mapfile -t containers < <(docker ps --filter label=service=portfolio --filter label=role=web --format '{{.ID}}')
[[ ${#containers[@]} -eq 1 ]] || { echo "expected one running portfolio web container, found ${#containers[@]}" >&2; exit 1; }
APP_CONTAINER=${containers[0]}

restic snapshots --latest 1 >/dev/null
install -d -o root -g root -m 0700 "$WORK_ROOT"
STAGE=$(mktemp -d "$WORK_ROOT/snapshot.XXXXXXXX")
install -d -m 0700 "$STAGE/active_storage"

docker pause "$APP_CONTAINER" >/dev/null
PAUSED=1
sqlite3 "$PRIMARY_DB" ".timeout 5000" ".backup '$STAGE/production.sqlite3'"
rsync -a --delete "$ASSET_DIR/" "$STAGE/active_storage/"
(
  cd "$STAGE"
  find production.sqlite3 active_storage -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
  sha256sum --check SHA256SUMS
  [[ "$(sqlite3 production.sqlite3 'PRAGMA integrity_check;')" == ok ]]
)
resume_app

(
  cd "$STAGE"
  restic backup --tag portfolio --tag nightly .
)
SNAPSHOT_CREATED=1
restic forget --tag portfolio --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check
logger -t portfolio-backup -- "backup, retention, and Restic structural verification completed"
```

```bash
chmod 0755 bin/backup
```

The EXIT trap covers command failures and explicit guard exits. It retries unpause and reports whether writes resumed instead of claiming success unconditionally.

- [ ] **Step 3: Add the systemd service and timer**

```ini
# ops/systemd/portfolio-backup.service
[Unit]
Description=Portfolio encrypted off-site backup
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/opt/portfolio/bin/backup
PrivateTmp=true
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
```

```ini
# ops/systemd/portfolio-backup.timer
[Unit]
Description=Run Portfolio backup nightly

[Timer]
OnCalendar=*-*-* 02:17:00
RandomizedDelaySec=15m
Persistent=true
Unit=portfolio-backup.service

[Install]
WantedBy=timers.target
```

- [ ] **Step 4: Run local static and SQLite checks**

```bash
command -v shellcheck >/dev/null || brew install shellcheck
bash -n bin/backup test/operations/sqlite_backup_test.sh
shellcheck bin/backup test/operations/sqlite_backup_test.sh
test/operations/sqlite_backup_test.sh
! grep -E 'production_(queue|cache|cable)\.sqlite3' bin/backup
grep -F 'resume_app' bin/backup
grep -F -- '--keep-daily 7 --keep-weekly 4 --keep-monthly 6' bin/backup
```

Expected: every command exits 0, ShellCheck prints nothing, and transient database names are absent.

The SQLite test proves the exact WAL-safe `.backup` operation locally. The Docker pause/unpause path, Restic upload, explicit snapshot restore, failure email, retention, and systemd timer require the real host and remain unchecked operator procedures in `docs/operations.md`.

- [ ] **Step 5: Commit prepared backup automation**

```bash
git add test/operations/sqlite_backup_test.sh bin/backup ops/systemd/portfolio-backup.service ops/systemd/portfolio-backup.timer
git commit -m "feat: prepare encrypted backup automation"
```

---

### Task 6: Prepare guarded restore and retry behavior

**Files:**

- Create: `bin/restore`

**Interfaces:**

- Consumes: `bin/restore SNAPSHOT_ID`, Task 5 snapshots and environment, and the newest current portfolio web container.
- Produces: a statically checked restore command designed to verify primary database/assets, recreate transient databases, retain `storage.before-*` data, restart a healthy app, and stop after unsafe post-replacement failure.

- [ ] **Step 1: Create the restore command**

```bash
#!/usr/bin/env bash
# bin/restore
set -euo pipefail
umask 077

readonly DATA_DIR=/var/lib/portfolio/storage
readonly WORK_ROOT=/var/lib/portfolio/backup-work
readonly ENV_FILE=/etc/portfolio/backup.env
readonly LOCK_FILE=/run/lock/portfolio-backup.lock

SNAPSHOT_ID=${1:-}
APP_CONTAINER=""
APP_IMAGE=""
RESTORE_DIR=""
ENV_COPY=""
OLD_DIR=""
STOPPED_BY_SCRIPT=0
REPLACED=0

notify_failure() {
  local message=$1
  logger -t portfolio-restore -- "$message" || true
  if [[ -n "${OPS_SMTP_URL:-}" && -n "${OPS_SMTP_USERNAME:-}" && -n "${OPS_SMTP_PASSWORD:-}" && -n "${OPS_EMAIL_FROM:-}" && -n "${OPS_EMAIL_TO:-}" ]]; then
    printf 'From: %s\r\nTo: %s\r\nSubject: Portfolio restore failed on %s\r\n\r\n%s\r\n' \
      "$OPS_EMAIL_FROM" "$OPS_EMAIL_TO" "$(hostname -f)" "$message" |
      curl --silent --show-error --fail --ssl-reqd \
        --url "$OPS_SMTP_URL" \
        --user "$OPS_SMTP_USERNAME:$OPS_SMTP_PASSWORD" \
        --mail-from "$OPS_EMAIL_FROM" \
        --mail-rcpt "$OPS_EMAIL_TO" \
        --upload-file - >/dev/null || logger -t portfolio-restore -- "SMTP failure alert could not be sent" || true
  fi
}

cleanup() {
  local status=$?
  local recovery_state=unchanged
  trap - EXIT
  set +e

  if [[ "$status" -ne 0 ]]; then
    if [[ "$REPLACED" == 0 && "$STOPPED_BY_SCRIPT" == 1 && -n "$APP_CONTAINER" ]]; then
      if docker start "$APP_CONTAINER" >/dev/null; then
        recovery_state=original-restarted
      else
        recovery_state=original-restart-failed
      fi
    elif [[ "$REPLACED" == 1 && -n "$APP_CONTAINER" ]]; then
      docker stop --time 10 "$APP_CONTAINER" >/dev/null 2>&1 || true
      recovery_state=replacement-stopped
    else
      recovery_state=left-as-found
    fi
    notify_failure "bin/restore snapshot=$SNAPSHOT_ID exited=$status replaced=$REPLACED recovery=$recovery_state previous=${OLD_DIR:-not-created}"
  fi

  [[ -z "$RESTORE_DIR" ]] || rm -rf -- "$RESTORE_DIR"
  [[ -z "$ENV_COPY" ]] || rm -f -- "$ENV_COPY"
  exit "$status"
}

require_command() {
  command -v "$1" >/dev/null || { echo "missing command: $1" >&2; return 1; }
}

require_env() {
  [[ -n "${!1:-}" ]] || { echo "missing environment variable: $1" >&2; return 1; }
}

trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo "bin/restore must run as root" >&2; exit 1; }
[[ $# -eq 1 && "$SNAPSHOT_ID" =~ ^[0-9a-fA-F]{8,64}$ ]] || { echo "usage: bin/restore SNAPSHOT_ID (8-64 hexadecimal characters; latest is forbidden)" >&2; exit 64; }
[[ -r "$ENV_FILE" ]] || { echo "cannot read $ENV_FILE" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for command_name in curl docker flock logger restic rsync sha256sum sqlite3; do
  require_command "$command_name"
done
for variable_name in RESTIC_REPOSITORY RESTIC_PASSWORD_FILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION; do
  require_env "$variable_name"
done
[[ -r "$RESTIC_PASSWORD_FILE" ]] || { echo "cannot read RESTIC_PASSWORD_FILE" >&2; exit 1; }

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another backup or restore is running" >&2; exit 75; }

EXPECTED_CONFIRMATION="RESTORE portfolio $SNAPSHOT_ID"
if [[ "${PORTFOLIO_RESTORE_CONFIRM:-}" != "$EXPECTED_CONFIRMATION" ]]; then
  printf 'This stops production and replaces %s. Type exactly: %s\n> ' "$DATA_DIR" "$EXPECTED_CONFIRMATION" >&2
  IFS= read -r confirmation
  [[ "$confirmation" == "$EXPECTED_CONFIRMATION" ]] || { echo "restore cancelled" >&2; exit 64; }
fi

mapfile -t running_containers < <(docker ps --filter label=service=portfolio --filter label=role=web --format '{{.ID}}')
[[ ${#running_containers[@]} -le 1 ]] || { echo "expected at most one running portfolio web container, found ${#running_containers[@]}" >&2; exit 1; }
if [[ ${#running_containers[@]} -eq 1 ]]; then
  APP_CONTAINER=${running_containers[0]}
else
  APP_CONTAINER=$(docker ps -a --latest --filter label=service=portfolio --filter label=role=web --format '{{.ID}}')
fi
[[ -n "$APP_CONTAINER" ]] || { echo "no portfolio web container found" >&2; exit 1; }
[[ "$(docker inspect --format '{{.State.Paused}}' "$APP_CONTAINER")" == false ]] || { echo "portfolio web container is paused; resolve backup state first" >&2; exit 1; }
APP_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$APP_CONTAINER")

restic snapshots "$SNAPSHOT_ID" >/dev/null
install -d -o root -g root -m 0700 "$WORK_ROOT"
RESTORE_DIR=$(mktemp -d "$WORK_ROOT/restore.XXXXXXXX")
ENV_COPY=$(mktemp "$WORK_ROOT/container-env.XXXXXXXX")
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$APP_CONTAINER" > "$ENV_COPY"
chmod 0600 "$ENV_COPY"

if [[ "$(docker inspect --format '{{.State.Running}}' "$APP_CONTAINER")" == true ]]; then
  docker stop --time 30 "$APP_CONTAINER" >/dev/null
  STOPPED_BY_SCRIPT=1
fi

restic restore "$SNAPSHOT_ID" --target "$RESTORE_DIR"
[[ -f "$RESTORE_DIR/production.sqlite3" ]] || { echo "snapshot lacks production.sqlite3" >&2; exit 1; }
[[ -d "$RESTORE_DIR/active_storage" ]] || { echo "snapshot lacks active_storage" >&2; exit 1; }
[[ -f "$RESTORE_DIR/SHA256SUMS" ]] || { echo "snapshot lacks SHA256SUMS" >&2; exit 1; }
for forbidden in production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3; do
  [[ ! -e "$RESTORE_DIR/$forbidden" ]] || { echo "snapshot unsafely contains $forbidden" >&2; exit 1; }
done
(
  cd "$RESTORE_DIR"
  sha256sum --check SHA256SUMS
)
[[ "$(sqlite3 "$RESTORE_DIR/production.sqlite3" 'PRAGMA integrity_check;')" == ok ]] || { echo "SQLite integrity_check failed" >&2; exit 1; }

RESTORE_TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
OLD_DIR="/var/lib/portfolio/storage.before-$RESTORE_TIMESTAMP"
[[ ! -e "$OLD_DIR" ]] || { echo "safety directory already exists: $OLD_DIR" >&2; exit 1; }
install -d -o root -g root -m 0700 "$OLD_DIR"
REPLACED=1
find "$DATA_DIR" -mindepth 1 -maxdepth 1 -exec mv -t "$OLD_DIR" -- {} +
chmod 0750 "$DATA_DIR"
chown 1000:1000 "$DATA_DIR"
install -o 1000 -g 1000 -m 0640 "$RESTORE_DIR/production.sqlite3" "$DATA_DIR/production.sqlite3"
install -d -o 1000 -g 1000 -m 0750 "$DATA_DIR/active_storage"
rsync -a "$RESTORE_DIR/active_storage/" "$DATA_DIR/active_storage/"
chown -R 1000:1000 "$DATA_DIR/active_storage"

docker run --rm \
  --volumes-from "$APP_CONTAINER" \
  --env-file "$ENV_COPY" \
  --entrypoint /rails/bin/rails \
  "$APP_IMAGE" db:prepare

docker start "$APP_CONTAINER" >/dev/null
for _attempt in $(seq 1 60); do
  if docker exec "$APP_CONTAINER" curl --fail --silent http://127.0.0.1/up >/dev/null 2>&1; then
    STOPPED_BY_SCRIPT=0
    logger -t portfolio-restore -- "restored $SNAPSHOT_ID; previous data retained at $OLD_DIR"
    printf 'restore complete: snapshot=%s previous=%s\n' "$SNAPSHOT_ID" "$OLD_DIR"
    exit 0
  fi
  sleep 1
done

echo "health check did not pass within 60 seconds" >&2
false # Trigger the EXIT trap with a failure status.
```

```bash
chmod 0755 bin/restore
```

The EXIT trap restarts the original app after every pre-replacement failure, including explicit guard exits. After replacement, any failure leaves the app stopped. If a prior failed restore already stopped the app, a retry finds the newest stopped portfolio container without pretending the script stopped it.

- [ ] **Step 2: Run static guard checks**

```bash
bash -n bin/restore
shellcheck bin/restore
grep -F 'latest is forbidden' bin/restore
grep -F 'docker ps -a --latest' bin/restore
grep -F 'sha256sum --check SHA256SUMS' bin/restore
grep -F "PRAGMA integrity_check" bin/restore
grep -F 'production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3' bin/restore
```

Expected: every command exits 0 and ShellCheck prints nothing.

- [ ] **Step 3: Verify restore remains Docker-host-only**

```bash
grep -F 'bin/restore must run as root' bin/restore
grep -F 'usage: bin/restore SNAPSHOT_ID' bin/restore
grep -F 'service=portfolio' bin/restore
grep -F 'role=web' bin/restore
! grep -F 'podman ' bin/restore
```

Expected: the root, explicit snapshot, and Docker label contracts are present; no Podman-specific production path exists. Do not run the restore command locally or remotely during implementation.

- [ ] **Step 4: Commit prepared restore**

```bash
git add bin/restore
git commit -m "feat: prepare guarded portfolio restore"
```

---

### Task 7: Rewrite operator and contributor documentation

**Files:**

- Replace: `README.md`
- Create: `docs/operations.md`

**Interfaces:**

- Consumes: Tasks 1–6 and the existing `bin/rails admin:create` task.
- Produces: exact development, deployment, backup, restore, and drill instructions.

- [ ] **Step 1: Replace README with concise start and deploy instructions**

````markdown
# Portfolio

A Rails 8.1 portfolio, blog, and single-owner content manager with English, French, and Vietnamese public pages.

## Requirements

For native development:

- Ruby 4.0.6
- SQLite 3
- libvips

For containerized development, use either:

- Podman 5.8+ with a Compose provider, or
- Docker with Docker Compose

Production deployment uses Kamal and requires Docker on the deployment workstation and Ubuntu server. Podman Compose is only for development.

## Start the development server

### Native Rails

First run:

```bash
bin/setup
```

Later runs:

```bash
bin/dev
```

Open <http://localhost:3000/en>. `bin/dev` runs Rails and the Tailwind watcher.

### Podman Compose

On macOS, start the Podman VM first:

```bash
podman machine start
podman compose up --build
```

Open <http://localhost:3000/en>. Stop with:

```bash
podman compose down
```

Reset containerized development data with:

```bash
podman compose down --volumes
```

### Docker Compose

```bash
docker compose up --build
```

Open <http://localhost:3000/en>. Stop with:

```bash
docker compose down
```

Reset containerized development data with:

```bash
docker compose down --volumes
```

Do not run Podman Compose and Docker Compose for this repository at the same time because both publish port 3000.

## Run tests

```bash
bin/rails test
bin/rails test:system
```

Run security and style checks with:

```bash
bin/brakeman --no-pager
bin/bundler-audit check --update
bin/rubocop
```

## Deploy manually

> These commands are operator-run after Phase 8 implementation. The implementation phase does not connect to a production server.

Deploy from the machine that has Docker, SSH access to the Ubuntu host, and the required production values loaded from the password manager.

Required environment variables:

```text
DEPLOY_HOST
APP_HOST
RAILS_MASTER_KEY
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
SMTP_ADDRESS
SMTP_PORT
SMTP_DOMAIN
SMTP_USERNAME
SMTP_PASSWORD
MAILER_FROM
```

First deployment:

```bash
bin/rails test
bin/rails test:system
bin/kamal setup
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
```

Later deployments:

```bash
bin/rails test
bin/rails test:system
bin/kamal deploy
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
```

Create or rotate the single owner account with production variables loaded:

```bash
bin/kamal app exec --interactive --reuse \
  -e "ADMIN_EMAIL:$ADMIN_EMAIL" \
  -e "ADMIN_PASSWORD:$ADMIN_PASSWORD" \
  "bin/rails admin:create"
```

Save the printed TOTP URI and recovery codes immediately.

See [`docs/operations.md`](docs/operations.md) for host provisioning, secret installation, rollback, backup, restore, and quarterly recovery drills.
````

- [ ] **Step 2: Write the operations runbook**

````markdown
# Portfolio operations

> **Operator-only manual runbook.** Phase 8 implementation prepares and locally validates files only. Nothing in this document is executed automatically by the implementation plan.

## Invariants

- One `portfolio` web container runs on one Ubuntu host behind `kamal-proxy`.
- `/var/lib/portfolio/storage` is the only application bind and is owned by `1000:1000` mode `0750`.
- `production.sqlite3` and `active_storage/` are backed up.
- Queue, cache, and cable SQLite files are never backed up or restored.
- Restic snapshots are encrypted client-side and retain 7 daily, 4 weekly, and 6 monthly points.
- Recovery objectives are RPO at most 24 hours and RTO at most 2 hours.
- Kamal deploys run from a Docker workstation. Podman Compose is development-only.

## Load deployment values

Load every variable in the Phase 8 environment contract from the owner's password manager. Do not source a tracked file.

```bash
for name in DEPLOY_HOST APP_HOST RAILS_MASTER_KEY ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN SMTP_USERNAME SMTP_PASSWORD MAILER_FROM; do
  test -n "${!name:-}" || { echo "missing $name" >&2; exit 1; }
done
```

## Provision the production host manually

```bash
ssh root@"$DEPLOY_HOST" 'set -eu
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io sqlite3 restic rsync curl
systemctl enable --now docker
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy
install -d -o deploy -g deploy -m 0700 /home/deploy/.ssh
install -o deploy -g deploy -m 0600 /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
install -d -o 1000 -g 1000 -m 0750 /var/lib/portfolio/storage
install -d -o root -g root -m 0700 /var/lib/portfolio/backup-work /etc/portfolio /opt/portfolio/bin
'
ssh deploy@"$DEPLOY_HOST" 'docker version --format "{{.Server.Version}}" && stat -c "%u:%g %a %n" /var/lib/portfolio/storage'
```

Require the final line to be:

```text
1000:1000 750 /var/lib/portfolio/storage
```

## Initial production setup

1. Point `APP_HOST` A/AAAA records to `DEPLOY_HOST`.
2. Run the production-host provisioning section above from the Docker workstation.
3. Run `bin/kamal setup`.
4. Require `curl -fsS "https://$APP_HOST/up"` to succeed.
5. Export `ADMIN_EMAIL` and a password of at least 14 characters, then run:

```bash
bin/kamal app exec --interactive --reuse \
  -e "ADMIN_EMAIL:$ADMIN_EMAIL" \
  -e "ADMIN_PASSWORD:$ADMIN_PASSWORD" \
  "bin/rails admin:create"
```

6. Save the TOTP URI and recovery codes, then verify password and TOTP sign-in in a private browser session.
7. Send a production SMTP message and confirm receipt.
8. Follow the backup installation and first-backup verification sections below.

## Routine deploy

```bash
git status --short
git rev-parse HEAD
bin/rails test
bin/rails test:system
bin/kamal deploy
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
bin/kamal app logs --since 5m | tail -200
```

Require a clean working tree, passing tests, healthy Kamal output, HTTP 200, and no boot exception. After job or mail changes, verify one scheduled publication and one production email.

## Rollback

```bash
bin/kamal app containers
read -r -p "Paste the prior deployed 40-character Git version: " PREVIOUS_VERSION
[[ "$PREVIOUS_VERSION" =~ ^[0-9a-f]{40}$ ]]
bin/kamal rollback "$PREVIOUS_VERSION"
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
```

Rollback changes the image only. Never roll back across an incompatible forward-only migration; deploy a corrective migration.

## Logs and health

```bash
bin/kamal app logs -f
curl --fail --silent --show-error --include "https://$APP_HOST/up"
ssh deploy@"$DEPLOY_HOST" 'docker ps --filter label=service=portfolio --filter label=role=web; sudo journalctl -u portfolio-backup.service -n 100 --no-pager'
```

Configure an external HTTPS uptime check for `https://$APP_HOST/up`.

## Verify production SMTP

```bash
bin/kamal app exec 'bin/rails runner '\''recipient = Profile.current.public_contact_email; ActionMailer::Base.mail(to: recipient, from: ENV.fetch("MAILER_FROM"), subject: "Portfolio production SMTP check", body: "SMTP delivery verified").deliver_now; puts "mail delivered to #{recipient}"'\'''
```

Confirm the message arrives before enabling scheduled operations.

## Install backup and restore automation manually

Generate one Restic password and save it in the password manager before continuing:

```bash
RESTIC_PASSWORD="$(openssl rand -base64 32)"
printf '%s\n' "$RESTIC_PASSWORD"
```

Export every backup variable from the manual operator environment contract, then install root-only configuration and scripts:

```bash
{
  printf 'RESTIC_REPOSITORY=%q\n' "$RESTIC_REPOSITORY"
  printf 'RESTIC_PASSWORD_FILE=%q\n' /etc/portfolio/restic-password
  printf 'AWS_ACCESS_KEY_ID=%q\n' "$AWS_ACCESS_KEY_ID"
  printf 'AWS_SECRET_ACCESS_KEY=%q\n' "$AWS_SECRET_ACCESS_KEY"
  printf 'AWS_DEFAULT_REGION=%q\n' "$AWS_DEFAULT_REGION"
  printf 'OPS_SMTP_URL=%q\n' "$OPS_SMTP_URL"
  printf 'OPS_SMTP_USERNAME=%q\n' "$OPS_SMTP_USERNAME"
  printf 'OPS_SMTP_PASSWORD=%q\n' "$OPS_SMTP_PASSWORD"
  printf 'OPS_EMAIL_FROM=%q\n' "$OPS_EMAIL_FROM"
  printf 'OPS_EMAIL_TO=%q\n' "$OPS_EMAIL_TO"
} | ssh deploy@"$DEPLOY_HOST" 'sudo install -o root -g root -m 0600 /dev/stdin /etc/portfolio/backup.env'
printf '%s' "$RESTIC_PASSWORD" | ssh deploy@"$DEPLOY_HOST" 'sudo install -o root -g root -m 0600 /dev/stdin /etc/portfolio/restic-password'
scp bin/backup bin/restore deploy@"$DEPLOY_HOST":/tmp/
scp ops/systemd/portfolio-backup.service ops/systemd/portfolio-backup.timer deploy@"$DEPLOY_HOST":/tmp/
ssh deploy@"$DEPLOY_HOST" 'sudo install -o root -g root -m 0755 /tmp/backup /opt/portfolio/bin/backup
sudo install -o root -g root -m 0755 /tmp/restore /opt/portfolio/bin/restore
sudo install -o root -g root -m 0644 /tmp/portfolio-backup.service /etc/systemd/system/portfolio-backup.service
sudo install -o root -g root -m 0644 /tmp/portfolio-backup.timer /etc/systemd/system/portfolio-backup.timer
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic init'\''
sudo systemctl daemon-reload
sudo systemctl enable --now portfolio-backup.timer
sudo systemctl list-timers portfolio-backup.timer --no-pager'
```

If `restic init` reports an existing repository, stop and verify its password with `restic snapshots`; never reinitialize it.

## Verify the first production backup manually

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service
sudo systemctl status portfolio-backup.service --no-pager'
SNAPSHOT_ID="$(ssh deploy@"$DEPLOY_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio --latest 1 --json'\''' | ruby -rjson -e 'snapshots = JSON.parse(STDIN.read); abort "no portfolio snapshot" if snapshots.empty?; puts snapshots.last.fetch("id")')"
printf 'snapshot=%s\n' "$SNAPSHOT_ID"
ssh deploy@"$DEPLOY_HOST" "sudo SNAPSHOT_ID='$SNAPSHOT_ID' bash -s" <<'REMOTE'
set -euo pipefail
set -a
source /etc/portfolio/backup.env
set +a
verify_dir=$(mktemp -d /var/lib/portfolio/backup-work/verify.XXXXXXXX)
trap 'rm -rf "$verify_dir"' EXIT
restic restore "$SNAPSHOT_ID" --target "$verify_dir"
cd "$verify_dir"
sha256sum --check SHA256SUMS
test "$(sqlite3 production.sqlite3 'PRAGMA integrity_check;')" = ok
test -d active_storage
for forbidden in production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3; do
  test ! -e "$forbidden"
done
restic ls "$SNAPSHOT_ID"
REMOTE
```

Require `status=0/SUCCESS`, every manifest entry ending in `OK`, SQLite integrity `ok`, and no transient databases in the snapshot.

## Verify post-pause failure recovery manually

Use a temporary fake `rsync` so the command fails after pausing without changing production data:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
fake_dir=$(mktemp -d /var/lib/portfolio/backup-work/fail-rsync.XXXXXXXX)
trap 'rm -rf "$fake_dir"' EXIT
cat > "$fake_dir/rsync" <<'SCRIPT'
#!/usr/bin/env bash
exit 42
SCRIPT
chmod 0755 "$fake_dir/rsync"
set +e
env PATH="$fake_dir:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" /opt/portfolio/bin/backup
status=$?
set -e
test "$status" -ne 0
container=$(docker ps -q --filter label=service=portfolio --filter label=role=web)
test -n "$container"
test "$(docker inspect --format '{{.State.Paused}}' "$container")" = false
REMOTE
```

Require Docker to report `false` and the operational address to receive a failure message containing `resumed=1`. Then rerun the normal service and require success:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service'
```

## Manual backup

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service
sudo systemctl status portfolio-backup.service --no-pager
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio'\'''
```

Success requires `status=0/SUCCESS`, a new snapshot, and an unpaused web container. A nonzero result is an incident: verify Docker reports `Paused=false`, read the journal, correct credentials/network/disk capacity, rerun the backup, and verify a new snapshot.

## Production restore

1. List snapshots and select one explicit hexadecimal ID:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio'\'''
read -r -p "Paste the snapshot ID: " SNAPSHOT_ID
[[ "$SNAPSHOT_ID" =~ ^[0-9a-fA-F]{8,64}$ ]] || { echo "invalid snapshot ID" >&2; exit 64; }
```

2. Record incident start UTC and snapshot UTC. Record an accepted RPO breach if the snapshot is older than 24 hours.
3. Require free space under `/var/lib/portfolio` greater than twice the snapshot size.
4. Restore interactively:

```bash
ssh -t deploy@"$DEPLOY_HOST" "sudo /opt/portfolio/bin/restore $SNAPSHOT_ID"
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
bin/kamal app exec 'bin/rails runner '\''puts({projects: Project.count, posts: Post.count, blobs: ActiveStorage::Blob.count, contacts: ContactMessage.count}.inspect)'\'''
```

5. Sign in, open a project image and each localized résumé PDF, submit a contact message, and verify scheduled publishing.
6. Keep the printed `storage.before-*` directory until owner acceptance. Remove only the exact validated path:

```bash
[[ "$VERIFIED_OLD_DIR" =~ ^/var/lib/portfolio/storage\.before-[0-9]{8}T[0-9]{6}Z$ ]] || { echo "invalid retained-data path" >&2; exit 64; }
ssh deploy@"$DEPLOY_HOST" "sudo test -d '$VERIFIED_OLD_DIR' && sudo rm -rf -- '$VERIFIED_OLD_DIR'"
```

7. Record restore end UTC, snapshot age, elapsed minutes, SQLite result, asset result, smoke result, operator, and incident link.

After a post-replacement failure, the app remains stopped and the prior data remains under the printed `storage.before-*` path. Inspect both directories. Retry the same explicit snapshot or restore the saved contents into the stable bind while the container stays stopped. Never rename the bind directory and never delete with a wildcard.

## Quarterly clean-server restore drill

Run before launch, every quarter, and after every backup-process change.

1. Create a disposable AMD64 Ubuntu 24.04 host, export `DRILL_HOST`, point `DRILL_APP_HOST` to it, and verify DNS.
2. Create a known production database-and-asset probe:

```bash
DRILL_TOKEN="restore-drill-$(date -u +%Y%m%dT%H%M%SZ)"
RESULT="$(bin/kamal app exec --reuse "bin/rails runner 'blob=ActiveStorage::Blob.create_and_upload!(io: StringIO.new(\"$DRILL_TOKEN\"), filename: \"restore-drill.txt\", content_type: \"text/plain\"); puts \"#{blob.id}:#{blob.checksum}\"'" | tail -n 1)"
printf '%s\n' "$RESULT"
```

3. Run a production backup and capture its explicit ID:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service'
SNAPSHOT_ID="$(ssh deploy@"$DEPLOY_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio --latest 1 --json'\''' | ruby -rjson -e 'snapshots = JSON.parse(STDIN.read); abort "no portfolio snapshot" if snapshots.empty?; puts snapshots.last.fetch("id")')"
START_EPOCH="$(date +%s)"
```

4. In a fresh shell, set `DEPLOY_HOST="$DRILL_HOST"` and `APP_HOST="$DRILL_APP_HOST"`, provision the host, and run `bin/kamal setup`.
5. Install `/etc/portfolio/backup.env`, `/etc/portfolio/restic-password`, and `/opt/portfolio/bin/restore` on the drill host. Do not enable the backup timer.
6. Restore with confirmation bound to the selected ID:

```bash
ssh deploy@"$DRILL_HOST" "sudo PORTFOLIO_RESTORE_CONFIRM='RESTORE portfolio $SNAPSHOT_ID' /opt/portfolio/bin/restore '$SNAPSHOT_ID'"
```

7. Prove database integrity, asset bytes, HTTPS, and fresh transient databases:

```bash
curl --fail --silent --show-error "https://$DRILL_APP_HOST/up" >/dev/null
ssh deploy@"$DRILL_HOST" 'test "$(sqlite3 /var/lib/portfolio/storage/production.sqlite3 "PRAGMA integrity_check;")" = ok; for db in production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3; do test -f "/var/lib/portfolio/storage/$db"; done'
DEPLOY_HOST="$DRILL_HOST" APP_HOST="$DRILL_APP_HOST" bin/kamal app exec --reuse "bin/rails runner 'blob=ActiveStorage::Blob.find(${RESULT%%:*}); abort unless blob.checksum == \"${RESULT#*:}\"; abort unless blob.download == \"$DRILL_TOKEN\"; puts \"asset verified\"'"
END_EPOCH="$(date +%s)"
printf 'RTO minutes: %d\n' "$(( (END_EPOCH - START_EPOCH + 59) / 60 ))"
```

8. Download and verify all Restic repository data independently:

```bash
ssh deploy@"$DRILL_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic check --read-data-subset=100%'\'''
```

9. Record snapshot ID/time, operator, RPO age, RTO minutes, `integrity_check=ok`, asset result, HTTPS result, and Restic result in the private operations record.
10. Purge the production probe only after recording success:

```bash
bin/kamal app exec --reuse "bin/rails runner 'ActiveStorage::Blob.find(${RESULT%%:*}).purge; puts \"probe removed\"'"
```

11. Delete the drill host and DNS record.

Acceptance values:

```text
integrity_check=ok
asset_download=verified
https_health=200
restic_check=no_errors
rpo_hours<=24
rto_minutes<=120
```

## Security and capacity maintenance

Monthly:

```bash
bundle outdated
bin/bundler-audit check --update
ssh deploy@"$DEPLOY_HOST" 'sudo apt-get update && sudo apt-get -y upgrade && sudo reboot'
for attempt in $(seq 1 60); do
  curl --fail --silent "https://$APP_HOST/up" >/dev/null && break
  sleep 2
done
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
ssh deploy@"$DEPLOY_HOST" 'df -h /var/lib/portfolio; sudo systemctl status portfolio-backup.timer --no-pager'
```

Apply critical updates sooner. After reboot, require health, one running web container, an active timer, and enough free space for the data directory plus backup staging.

## Manual production acceptance and phase tag

Only the operator performs this section after deployment, the first verified backup, the forced failure test, and the clean-server restore drill.

```bash
curl --fail --silent --show-error --include "https://$APP_HOST/up"
bin/kamal app details
ssh deploy@"$DEPLOY_HOST" 'set -eu
containers=$(docker ps -q --filter label=service=portfolio --filter label=role=web | wc -l)
test "$containers" -eq 1
test "$(stat -c %u:%g /var/lib/portfolio/storage)" = 1000:1000
test -f /var/lib/portfolio/storage/production.sqlite3
test -d /var/lib/portfolio/storage/active_storage
test "$(sqlite3 /var/lib/portfolio/storage/production.sqlite3 "PRAGMA integrity_check;")" = ok
sudo systemctl is-enabled --quiet portfolio-backup.timer
sudo systemctl is-active --quiet portfolio-backup.timer'
```

Confirm production SMTP, Solid Queue, persistence across restart, rollback, explicit snapshot restore, post-pause failure recovery, and the clean-server drill. Require recorded RPO at most 24 hours and RTO at most 120 minutes. Keep secrets, host addresses, snapshot IDs, and private drill evidence outside Git.

After every production acceptance item passes:

```bash
git status --short
git tag -a portfolio-v4-phase-8 -m "Accept portfolio v4 phase 8 operations"
git show --stat --oneline portfolio-v4-phase-8
```

Do not create this tag during implementation or before manual production acceptance.
````

- [ ] **Step 3: Verify documentation commands and links**

```bash
test -s README.md
test -s docs/operations.md
grep -F 'podman compose up --build' README.md
grep -F 'docker compose up --build' README.md
grep -F 'bin/kamal deploy' README.md
grep -F 'bin/rails admin:create' README.md docs/operations.md
grep -F 'production.sqlite3' docs/operations.md
grep -F 'restic check --read-data-subset=100%' docs/operations.md
! grep -E 'docker-compose up|podman-compose up' README.md
```

Expected: every positive check succeeds and deprecated command spellings are absent.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md docs/operations.md
git commit -m "docs: document development and operations"
```

---

### Task 8: Complete local acceptance and hand off manual operations

**Files:**

- Verify only; no source changes expected.

**Interfaces:**

- Consumes: Tasks 1–7.
- Produces: operations files prepared and locally verified, with production acceptance explicitly left to the operator.

- [ ] **Step 1: Run local repository checks**

```bash
bash -n bin/backup bin/restore test/operations/sqlite_backup_test.sh test/operations/backup_restore_safety_test.sh
shellcheck bin/backup bin/restore test/operations/sqlite_backup_test.sh test/operations/backup_restore_safety_test.sh
test/operations/sqlite_backup_test.sh
test/operations/backup_restore_safety_test.sh
bin/rails test
bin/rails test:system
bin/rails zeitwerk:check
podman compose config
podman compose build
```

Expected: every command exits 0. No command contacts a production or drill host.

- [ ] **Step 2: Run local application and image checks with Podman**

```bash
podman compose up --detach
for attempt in $(seq 1 30); do
  curl --fail --silent http://127.0.0.1:3000/up >/dev/null && break
  sleep 1
done
curl --fail --silent --show-error http://127.0.0.1:3000/up >/dev/null
podman compose down
podman build --platform linux/amd64 -t portfolio:phase-8-acceptance .
podman image inspect portfolio:phase-8-acceptance \
  --format '{{.Config.User}} {{json .Config.Cmd}}'
```

Expected: local health succeeds, the production image builds, and inspection contains user `1000:1000` with Thruster/Rails server command.

- [ ] **Step 3: Parse production configuration using dummy values only**

```bash
DEPLOY_HOST=192.0.2.10 \
APP_HOST=portfolio.invalid \
RAILS_MASTER_KEY=dummy-master-key \
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=dummy-primary-key \
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=dummy-deterministic-key \
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=dummy-derivation-salt \
SMTP_ADDRESS=smtp.invalid SMTP_PORT=587 SMTP_DOMAIN=portfolio.invalid \
SMTP_USERNAME=dummy-smtp-user SMTP_PASSWORD=dummy-smtp-password \
MAILER_FROM=owner@portfolio.invalid \
bin/kamal config >/dev/null
```

Expected: configuration parsing exits 0 without network access.

- [ ] **Step 4: Verify the manual boundary is explicit**

```bash
grep -F 'operator-run after Phase 8 implementation' README.md
grep -F 'Operator-only manual runbook' docs/operations.md
grep -F 'The implementation phase does not connect to a production server' README.md
grep -F 'Nothing in this document is executed automatically' docs/operations.md
git status --short
```

Expected: all boundary checks pass and Git status is empty after the planned commits.

- [ ] **Step 5: Record the handoff without production claims**

Report exactly:

```text
Phase 8 operations files are prepared and locally verified.
No production or drill host was contacted.
Deployment, backup initialization, production backup verification, restore drill, and production acceptance remain manual operator work in docs/operations.md.
```

Do not run `ssh`, `scp`, `kamal setup`, `kamal deploy`, `kamal rollback`, remote `systemctl`, `restic init`, production SMTP checks, DNS changes, or `git tag` during phase implementation.

## Risks and Rollback Boundaries

- **Font availability:** fonts are committed same-origin assets under OFL; the system sans-serif stack remains the loading fallback.
- **Compose portability:** only Compose-spec features shared by Podman and Docker are used. Production does not use Compose.
- **Kamal workstation:** Kamal's builder and localhost registry require Docker. Deploy from the Docker machine rather than introducing a local shim.
- **Build-time secrets:** `SECRET_KEY_BASE_DUMMY=1` must continue to boot production for asset compilation without `APP_HOST` or encryption keys.
- **Phase boundary:** implementation prepares files and performs local checks only. Remote commands are documentation, not executable checklist steps.
- **SQLite/asset skew:** Docker pause covers both `.backup` and `rsync`; the operator must run the documented post-pause failure drill on the real host.
- **Unpause failure:** the backup retries unpause and reports the actual resumed state. Actual Docker behavior remains unverified until the operator runs the manual drill.
- **Bind ownership:** Kamal does not repair host bind ownership; the operator checks numeric `1000:1000` during provisioning and after restore.
- **Transient duplication:** queue/cache/cable databases are recreated. Durable publication and delivery state remains in the primary database.
- **Restore data loss:** only an explicit hexadecimal snapshot and exact confirmation are accepted. Old data remains until manual approval.
- **Restore retry:** a failed replacement leaves the app stopped; the next explicit retry can locate the newest stopped portfolio container.
- **Forward-only migrations:** image rollback never reverses schema changes. Correct incompatible migrations forward.
- **Repository cost:** nightly checks validate structure; the operator runs full data reads during initial acceptance and quarterly drills instead of downloading the repository every night.
- **Manual acceptance:** local success does not prove DNS, TLS, SMTP, Docker labels, Restic credentials, systemd timing, backup completeness, or restore safety. Do not claim production readiness or tag the phase until the operator completes the runbook.
- **Single-server downtime:** backup pause, restore, and host updates cause brief downtime by design when the operator eventually runs them. Add replication only after measured requirements justify it.
