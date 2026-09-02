# Portfolio v4 Phase 8 Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy the accepted Rails application as one persistent application container on one Ubuntu server and prove encrypted nightly backup and guarded clean-server restore of the primary SQLite database and every Active Storage object.

**Architecture:** Kamal 2 deploys the Rails 8.1 image through `kamal-proxy`; the proxy obtains and terminates TLS, while Thruster forwards to Puma and Puma starts Solid Queue in-process. One host bind, `/var/lib/portfolio/storage:/rails/storage`, persists the primary, queue, cache, and cable SQLite files plus Active Storage; host-side scripts pause the running application only long enough to take a SQLite online backup and stable asset copy, then Restic encrypts and transfers only the primary snapshot and assets to S3-compatible storage.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, SQLite 3, Active Storage Disk service, Solid Queue, Puma, Thruster, Docker, Kamal 2.8+, kamal-proxy, Ubuntu 24.04 LTS, Bash, systemd, Restic, S3-compatible object storage, curl SMTP

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

## Preconditions and fixed assumptions

- Phases 1–7 are accepted and the working tree is clean.
- `Gemfile.lock` resolves Ruby `4.0.6`, Rails `8.1.x`, `kamal ~> 2.8`, `solid_queue`, `thruster`, and `bootsnap`.
- The production server and the quarterly drill server are AMD64 Ubuntu 24.04 hosts reachable by SSH.
- `APP_HOST` is the production DNS name only, without scheme or path; its A/AAAA records point to `DEPLOY_HOST` before `kamal setup`.
- `DRILL_APP_HOST` is a separate DNS name whose A/AAAA records point to `DRILL_HOST` only during a drill.
- TCP 22, 80, and 443 are allowed inbound. No other application port is public.
- The image runs as numeric UID/GID `1000:1000`; the persistent bind is owned by that numeric identity even if the host account has another name.
- Active Storage production objects live only below `/var/lib/portfolio/storage/active_storage`. This separation is mandatory because queue/cache/cable databases must not enter backups.
- The backup and restore scripts run as root on the application host. They use Docker labels `service=portfolio` and `role=web` to identify the sole running application container.
- Restic encryption uses a randomly generated 32-byte password stored at `/etc/portfolio/restic-password`, separate from Rails credentials and S3 credentials. Restic encrypts repository content before upload; S3 server-side encryption is optional defense in depth, not the encryption boundary.
- The nightly operation may briefly make the site unavailable while `docker pause` freezes the sole app container. Network upload, retention, and repository verification happen after `docker unpause`.
- A restore always stops the app, restores into a temporary directory, verifies every manifest checksum and `PRAGMA integrity_check`, preserves the previous data directory, prepares fresh queue/cache/cable databases, and only then starts the app.

## File map

| Path                                    | Action        | Responsibility                                                                                                         |
| --------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `config/database.yml`                   | Modify        | Put all production SQLite files under the bind-mounted directory with distinct primary/queue/cache/cable files.        |
| `config/storage.yml`                    | Modify        | Put production Active Storage objects under `storage/active_storage`.                                                  |
| `config/environments/production.rb`     | Modify        | Enforce TLS assumptions, stdout logging, local uploads, production SMTP, and Solid Queue.                              |
| `config/puma.rb`                        | Verify/modify | Start the Solid Queue supervisor only when `SOLID_QUEUE_IN_PUMA` is set.                                               |
| `config/routes.rb`                      | Verify/modify | Keep Rails' `/up` health endpoint enabled.                                                                             |
| `test/controllers/health_check_test.rb` | Create        | Protect the public health contract.                                                                                    |
| `Dockerfile`                            | Replace       | Build the production Ruby image and run Thruster/Puma as UID 1000.                                                     |
| `.dockerignore`                         | Modify        | Keep local data and secrets out of the image context.                                                                  |
| `config/deploy.yml`                     | Replace       | Define one-host Kamal deployment, local registry, TLS proxy, health check, env, bind, and log rotation.                |
| `.kamal/secrets`                        | Modify        | Resolve deploy secrets from local environment without committing values.                                               |
| `bin/backup`                            | Create        | Pause writes, snapshot primary SQLite and assets, resume, encrypt/upload, retain, verify, and alert on error.          |
| `bin/restore`                           | Create        | Confirm intent, stop writes, fetch and verify one snapshot, replace data safely, create transient DBs, and smoke-test. |
| `ops/systemd/portfolio-backup.service`  | Create        | Run the host backup command as root.                                                                                   |
| `ops/systemd/portfolio-backup.timer`    | Create        | Trigger one persistent nightly backup.                                                                                 |
| `docs/operations.md`                    | Create        | Give exact provisioning, deploy, rollback, backup, restore, and drill runbooks.                                        |

## Environment contract

No listed variable has an implicit production default. Store values in the owner's password manager; export deploy values only in the local shell running Kamal, and install backup values in root-readable host files.

### Kamal/deploy workstation

| Variable                  | Secret | Exact meaning/format                                                 |
| ------------------------- | ------ | -------------------------------------------------------------------- |
| `DEPLOY_HOST`             | No     | Production IPv4, IPv6, or SSH-resolvable host name. One host only.   |
| `APP_HOST`                | No     | Production HTTPS DNS name, without `https://`, port, slash, or path. |
| `RAILS_MASTER_KEY`        | Yes    | Exact content of `config/master.key`; no trailing spaces.            |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | Yes | Phase 3 production encryption primary key. |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | Yes | Phase 3 production deterministic encryption key. |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Yes | Phase 3 production encryption derivation salt. |
| `SMTP_ADDRESS`            | No     | SMTP provider DNS name.                                              |
| `SMTP_PORT`               | No     | Integer submission port; use `587` for STARTTLS.                     |
| `SMTP_DOMAIN`             | No     | EHLO domain controlled by the owner.                                 |
| `SMTP_USERNAME`           | Yes    | Provider submission username.                                        |
| `SMTP_PASSWORD`           | Yes    | Provider submission password.                                        |
| `MAILER_FROM`             | No     | Verified RFC 5322 sender address.                                    |
| `DRILL_HOST`              | No     | Disposable clean Ubuntu host used only by the restore drill.         |
| `DRILL_APP_HOST`          | No     | Drill-only DNS name, without scheme or path.                         |

`RAILS_MASTER_KEY`, infrastructure credentials, TOTP recovery data, and Restic credentials remain separate password-manager entries. Never place them in Git, shell history, systemd unit files, or `docs/operations.md`.

### Backup/restore host

`/etc/portfolio/backup.env` is root-owned mode `0600` and contains shell-quoted assignments for exactly these values:

| Variable                | Secret           | Exact meaning/format                                                                                                                                    |
| ----------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RESTIC_REPOSITORY`     | No               | Restic `s3:` URL for the provider endpoint and bucket, with repository path ending in `/portfolio`; the complete value comes from the password manager. |
| `RESTIC_PASSWORD_FILE`  | Yes-by-reference | Always `/etc/portfolio/restic-password`.                                                                                                                |
| `AWS_ACCESS_KEY_ID`     | Yes              | S3 key restricted to the repository prefix.                                                                                                             |
| `AWS_SECRET_ACCESS_KEY` | Yes              | Matching S3 secret key.                                                                                                                                 |
| `AWS_DEFAULT_REGION`    | No               | Region required by the S3-compatible provider.                                                                                                          |
| `OPS_SMTP_URL`          | No               | Complete curl `smtp://` submission URL, normally using STARTTLS port `587`.                                                                             |
| `OPS_SMTP_USERNAME`     | Yes              | SMTP submission username.                                                                                                                               |
| `OPS_SMTP_PASSWORD`     | Yes              | SMTP submission password.                                                                                                                               |
| `OPS_EMAIL_FROM`        | No               | Verified sender address.                                                                                                                                |
| `OPS_EMAIL_TO`          | Yes              | Owner operational alert address.                                                                                                                        |

The S3 policy permits list/get/put/delete only for the selected bucket repository prefix. Delete is required by `restic forget --prune`; bucket-wide administration is not.

---

### Task 1: Fix the persistent runtime and health contracts

**Files:**

- Modify: `config/database.yml`
- Modify: `config/storage.yml`
- Modify: `config/environments/production.rb`
- Modify: `config/puma.rb`
- Modify: `config/routes.rb`
- Create: `test/controllers/health_check_test.rb`

**Interfaces:**

- Consumes: Phase 5's `config/recurring.yml` and Solid Queue installation; Phase 6's Action Mailer and `Profile.current.public_contact_email` recipient lookup.
- Produces: `/up`, primary database path `/rails/storage/production.sqlite3`, transient database paths under `/rails/storage`, asset root `/rails/storage/active_storage`, and `SOLID_QUEUE_IN_PUMA=true` behavior.

- [ ] **Step 1: Add the failing health contract test**

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

- [ ] **Step 2: Run the focused test and confirm the current contract**

Run:

```bash
bin/rails test test/controllers/health_check_test.rb
```

Expected before route correction: `FAIL` with a 404 if the generated health route was removed. If it already passes, keep the test and do not duplicate the route.

- [ ] **Step 3: Make the production database layout exact**

Retain the existing development/test sections and make the production section exactly:

```yaml
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

Do not combine these databases. Only `production.sqlite3` is irreplaceable and restored; queue/cache/cable are recreated from schemas after restore.

- [ ] **Step 4: Isolate production Active Storage objects from SQLite files**

Add this service without changing development/test service names:

```yaml
production:
  service: Disk
  root: <%= Rails.root.join("storage/active_storage") %>
```

In `config/environments/production.rb`, set the following exact operational settings, preserving unrelated Phase 1–7 settings:

```ruby
config.active_storage.service = :production
config.active_job.queue_adapter = :solid_queue

config.assume_ssl = true
config.force_ssl = true
config.action_dispatch.ssl_options = { hsts: { subdomains: false } }

config.log_tags = [:request_id]
config.logger = ActiveSupport::TaggedLogging.logger($stdout)
config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
config.silence_healthcheck_path = "/up"

config.action_mailer.default_url_options = {
  host: ENV.fetch("APP_HOST"),
  protocol: "https"
}
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
```

Confirm Phase 6's mailer reads `ENV.fetch("MAILER_FROM", "portfolio@example.test")` for its sender and `Profile.current.public_contact_email` for its recipient. Production always supplies `MAILER_FROM`; the test default never ships as a usable sender.

- [ ] **Step 5: Enable Solid Queue in the sole Puma process**

Ensure `config/puma.rb` contains this line exactly once after `plugin :tmp_restart`:

```ruby
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```

Ensure `config/routes.rb` contains this route exactly once:

```ruby
get "up" => "rails/health#show", as: :rails_health_check
```

- [ ] **Step 6: Verify configuration, health, and all accepted behavior**

Run:

```bash
bin/rails test test/controllers/health_check_test.rb
bin/rails runner 'puts Rails.application.config.active_job.queue_adapter'
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

Expected:

```text
solid_queue
[["storage/production.sqlite3", "storage/production_cache.sqlite3", "storage/production_queue.sqlite3", "storage/production_cable.sqlite3"], :production]
```

The two full-suite commands exit 0.

- [ ] **Step 7: Commit the runtime contract**

```bash
git add config/database.yml config/storage.yml config/environments/production.rb config/puma.rb config/routes.rb test/controllers/health_check_test.rb
git commit -m "chore: define production runtime contract"
```

---

### Task 2: Build and deploy the single application container with TLS

**Files:**

- Replace: `Dockerfile`
- Modify: `.dockerignore`
- Replace: `config/deploy.yml`
- Modify: `.kamal/secrets`

**Interfaces:**

- Consumes: Task 1's `/up`, storage paths, SMTP contract, and Solid Queue Puma gate.
- Produces: one `portfolio-web-*` app container, `https://$APP_HOST`, automatic TLS, local-registry deployment, stdout logs, and `/var/lib/portfolio/storage:/rails/storage`.

- [ ] **Step 1: Replace the production Dockerfile**

```dockerfile
# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .
RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=1000:1000 /rails /rails

USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
```

Keep `bin/docker-entrypoint` executable and ensure it runs `bin/rails db:prepare` before `exec "$@"`; this creates fresh transient databases on each newly deployed/restored data directory.

- [ ] **Step 2: Prevent local state and secrets entering the image**

Ensure `.dockerignore` contains:

```text
/.git/
/.kamal/secrets
/config/master.key
/log/*
!/log/.keep
/storage/*
!/storage/.keep
/tmp/*
!/tmp/.keep
```

- [ ] **Step 3: Write the exact Kamal configuration**

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

`localhost:5555` is Kamal's temporary local registry and avoids adding a permanent image-registry service. Keep one web host and no accessory/container role.

- [ ] **Step 4: Resolve Kamal secrets without storing values**

```bash
# .kamal/secrets
RAILS_MASTER_KEY=${RAILS_MASTER_KEY:-$(cat config/master.key)}
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
SMTP_USERNAME=$SMTP_USERNAME
SMTP_PASSWORD=$SMTP_PASSWORD
```

Verify `.kamal/secrets` contains references only:

```bash
grep -Fx 'RAILS_MASTER_KEY=${RAILS_MASTER_KEY:-$(cat config/master.key)}' .kamal/secrets
grep -Fx 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' .kamal/secrets
grep -Fx 'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY' .kamal/secrets
grep -Fx 'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT' .kamal/secrets
grep -Fx 'SMTP_PASSWORD=$SMTP_PASSWORD' .kamal/secrets
```

Expected: exit 0 with no output.

- [ ] **Step 5: Build and inspect the image locally**

```bash
docker build --platform linux/amd64 -t portfolio:phase-8 .
docker inspect portfolio:phase-8 --format '{{.Config.User}} {{json .Config.ExposedPorts}} {{json .Config.Cmd}}'
```

Expected:

```text
1000:1000 {"80/tcp":{}} ["./bin/thrust","./bin/rails","server"]
```

- [ ] **Step 6: Provision the persistent host bind before first deploy**

With `DEPLOY_HOST` exported from the password manager:

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

Expected final line:

```text
1000:1000 750 /var/lib/portfolio/storage
```

- [ ] **Step 7: Preflight environment, DNS, and TLS ports**

```bash
for name in DEPLOY_HOST APP_HOST RAILS_MASTER_KEY ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN SMTP_USERNAME SMTP_PASSWORD MAILER_FROM; do
  test -n "${!name:-}" || { echo "missing $name" >&2; exit 1; }
done
dig +short "$APP_HOST"
nc -z "$DEPLOY_HOST" 22
```

Expected: every variable check is silent, DNS returns at least one address, and the SSH port check exits 0.

- [ ] **Step 8: Deploy and verify the proxy, TLS, health, mail, queue, and persistence**

```bash
bin/kamal setup
bin/kamal app details
curl --fail --silent --show-error --include "https://$APP_HOST/up"
bin/kamal app exec 'bin/rails runner '\''puts [Rails.env, Rails.application.config.active_job.queue_adapter, ENV.fetch("SOLID_QUEUE_IN_PUMA")].join(" ")'\'''
bin/kamal app exec 'bin/rails runner '\''recipient = Profile.current.public_contact_email; ActionMailer::Base.mail(to: recipient, from: ENV.fetch("MAILER_FROM"), subject: "Portfolio production SMTP check", body: "SMTP delivery verified").deliver_now; puts "mail delivered to #{recipient}"'\'''
ssh deploy@"$DEPLOY_HOST" 'docker ps --filter label=service=portfolio --filter label=role=web --format "{{.Names}}"; docker logs $(docker ps -q --filter label=service=portfolio --filter label=role=web) 2>&1 | grep -m1 "SolidQueue"'
```

Expected output includes:

```text
HTTP/2 200
production solid_queue true
mail delivered
portfolio-web-
```

Confirm the SMTP message arrives at `Profile.current.public_contact_email` before continuing.

Create a persistence probe, restart, and read it back:

```bash
PROBE="phase-8-$(date -u +%Y%m%dT%H%M%SZ)"
bin/kamal app exec "bin/rails runner 'File.write(Rails.root.join(\"storage/persistence-probe\"), \"$PROBE\")'"
ssh deploy@"$DEPLOY_HOST" 'docker restart $(docker ps -q --filter label=service=portfolio --filter label=role=web) >/dev/null'
sleep 10
bin/kamal app exec 'bin/rails runner '\''puts File.read(Rails.root.join("storage/persistence-probe"))'\'''
```

Expected: the final line is the exact value printed in `PROBE`. Remove only the probe afterward:

```bash
bin/kamal app exec 'rm /rails/storage/persistence-probe'
```

- [ ] **Step 9: Prove rollback does not replace the bind**

After a second deployment exists:

```bash
bin/kamal app containers
read -r -p "Paste the prior deployed 40-character Git version: " PREVIOUS_VERSION
[[ "$PREVIOUS_VERSION" =~ ^[0-9a-f]{40}$ ]]
bin/kamal rollback "$PREVIOUS_VERSION"
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
ssh deploy@"$DEPLOY_HOST" 'stat -c "%u:%g %n" /var/lib/portfolio/storage/production.sqlite3'
```

Expected: rollback exits 0, health exits 0, and the database remains owned by `1000:1000`. Never roll back across an incompatible forward-only migration; deploy a corrective migration instead.

- [ ] **Step 10: Commit deployment configuration**

```bash
git add Dockerfile .dockerignore config/deploy.yml .kamal/secrets
git commit -m "chore: deploy portfolio with kamal"
```

---

### Task 3: Implement encrypted nightly backup and failure reporting

**Files:**

- Create: `bin/backup`
- Create: `ops/systemd/portfolio-backup.service`
- Create: `ops/systemd/portfolio-backup.timer`

**Interfaces:**

- Consumes: Task 2's sole labeled container and persistent host bind; `/etc/portfolio/backup.env`; `/etc/portfolio/restic-password`.
- Produces: root-only `bin/backup`, Restic snapshots tagged `portfolio` and `nightly`, 7 daily/4 weekly/6 monthly retention, full repository data verification, and SMTP failure alerts.

- [ ] **Step 1: Create the host backup command**

```bash
#!/usr/bin/env bash
# bin/backup
set -Eeuo pipefail
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

notify_failure() {
  local message=$1
  logger -t portfolio-backup -- "$message"
  if [[ -n "${OPS_SMTP_URL:-}" && -n "${OPS_SMTP_USERNAME:-}" && -n "${OPS_SMTP_PASSWORD:-}" && -n "${OPS_EMAIL_FROM:-}" && -n "${OPS_EMAIL_TO:-}" ]]; then
    printf 'From: %s\r\nTo: %s\r\nSubject: Portfolio backup failed on %s\r\n\r\n%s\r\n' \
      "$OPS_EMAIL_FROM" "$OPS_EMAIL_TO" "$(hostname -f)" "$message" |
      curl --silent --show-error --fail --ssl-reqd \
        --url "$OPS_SMTP_URL" \
        --user "$OPS_SMTP_USERNAME:$OPS_SMTP_PASSWORD" \
        --mail-from "$OPS_EMAIL_FROM" \
        --mail-rcpt "$OPS_EMAIL_TO" \
        --upload-file - >/dev/null || logger -t portfolio-backup -- "SMTP failure alert could not be sent"
  fi
}

cleanup() {
  if [[ "$PAUSED" == 1 && -n "$APP_CONTAINER" ]]; then
    docker unpause "$APP_CONTAINER" >/dev/null 2>&1 || true
  fi
  [[ -z "$STAGE" ]] || rm -rf -- "$STAGE"
}

on_error() {
  local status=$1 line=$2
  trap - ERR
  set +e
  if [[ "$PAUSED" == 1 && -n "$APP_CONTAINER" ]]; then
    docker unpause "$APP_CONTAINER" >/dev/null
    PAUSED=0
  fi
  notify_failure "bin/backup exited $status at line $line; application writes were resumed; no successful snapshot was recorded"
  exit "$status"
}

require_command() { command -v "$1" >/dev/null || { echo "missing command: $1" >&2; return 1; }; }
require_env() { [[ -n "${!1:-}" ]] || { echo "missing environment variable: $1" >&2; return 1; }; }

trap cleanup EXIT
trap 'on_error $? $LINENO' ERR

[[ $EUID -eq 0 ]] || { echo "bin/backup must run as root" >&2; exit 1; }
[[ -r "$ENV_FILE" ]] || { echo "cannot read $ENV_FILE" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

for command_name in curl docker flock logger restic rsync sha256sum sqlite3; do require_command "$command_name"; done
for variable_name in RESTIC_REPOSITORY RESTIC_PASSWORD_FILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION OPS_SMTP_URL OPS_SMTP_USERNAME OPS_SMTP_PASSWORD OPS_EMAIL_FROM OPS_EMAIL_TO; do require_env "$variable_name"; done
[[ -r "$RESTIC_PASSWORD_FILE" ]] || { echo "cannot read RESTIC_PASSWORD_FILE" >&2; exit 1; }
[[ -f "$PRIMARY_DB" ]] || { echo "missing primary database: $PRIMARY_DB" >&2; exit 1; }
[[ -d "$ASSET_DIR" ]] || { echo "missing Active Storage directory: $ASSET_DIR" >&2; exit 1; }

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another backup or restore is running" >&2; exit 75; }

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
  [[ "$(sqlite3 production.sqlite3 'PRAGMA integrity_check;')" == ok ]]
)
docker unpause "$APP_CONTAINER" >/dev/null
PAUSED=0

(
  cd "$STAGE"
  restic backup --tag portfolio --tag nightly .
)
restic forget --tag portfolio --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check --read-data-subset=100%
logger -t portfolio-backup -- "backup, retention, and full Restic data verification completed"
```

Make it executable:

```bash
chmod 0755 bin/backup
```

The pause ends before `restic backup`; the `ERR` and `EXIT` traps independently attempt to unpause, so every failure path resumes writes. The snapshot contains only `production.sqlite3`, `active_storage/`, and `SHA256SUMS`.

- [ ] **Step 2: Add the nightly systemd service and timer**

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

`Persistent=true` runs a missed backup after boot, preserving the 24-hour RPO after a short outage.

- [ ] **Step 3: Run static safety checks**

Install ShellCheck on the development machine if absent, then run:

```bash
bash -n bin/backup
shellcheck bin/backup
! grep -E 'production_(queue|cache|cable)\.sqlite3' bin/backup
grep -F 'docker unpause' bin/backup
grep -F -- '--keep-daily 7 --keep-weekly 4 --keep-monthly 6' bin/backup
```

Expected: all commands exit 0; ShellCheck prints nothing; the exclusion grep prints nothing; the positive greps print the unpause and retention lines.

- [ ] **Step 4: Install root-only host configuration and initialize Restic**

Export all backup variables and a generated Restic password from the password manager. Generate the password once with:

```bash
RESTIC_PASSWORD="$(openssl rand -base64 32)"
printf '%s\n' "$RESTIC_PASSWORD"
```

Save that output in the password manager before running:

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
scp bin/backup deploy@"$DEPLOY_HOST":/tmp/portfolio-backup
scp ops/systemd/portfolio-backup.service ops/systemd/portfolio-backup.timer deploy@"$DEPLOY_HOST":/tmp/
ssh deploy@"$DEPLOY_HOST" 'sudo install -o root -g root -m 0755 /tmp/portfolio-backup /opt/portfolio/bin/backup
sudo install -o root -g root -m 0644 /tmp/portfolio-backup.service /etc/systemd/system/portfolio-backup.service
sudo install -o root -g root -m 0644 /tmp/portfolio-backup.timer /etc/systemd/system/portfolio-backup.timer
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic init'\''
sudo systemctl daemon-reload
sudo systemctl enable --now portfolio-backup.timer
sudo systemctl list-timers portfolio-backup.timer --no-pager
'
```

Expected Restic output includes:

```text
created restic repository
```

Expected systemd output contains `portfolio-backup.timer`, `NEXT`, and `LEFT`. If `restic init` reports that the repository already exists, stop and verify its password with `restic snapshots`; do not overwrite or reinitialize it.

- [ ] **Step 5: Run and inspect the first real backup**

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service
sudo systemctl status portfolio-backup.service --no-pager
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio; restic ls latest'\''
'
```

Expected status: `Active: inactive (dead)` and `status=0/SUCCESS`. Restic output includes one snapshot and exactly these roots:

```text
/SHA256SUMS
/production.sqlite3
/active_storage
```

It must not include `production_queue.sqlite3`, `production_cache.sqlite3`, or `production_cable.sqlite3`.

- [ ] **Step 6: Prove the failure channel without damaging a successful repository**

Temporarily run with an invalid repository only in the command environment:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; export RESTIC_REPOSITORY="s3:https://127.0.0.1:1/unreachable"; /opt/portfolio/bin/backup'\''; test $? -ne 0
sleep 15
'
```

Expected: command exits nonzero, the application is not paused (`docker inspect --format '{{.State.Paused}}'` prints `false`), and `OPS_EMAIL_TO` receives subject `Portfolio backup failed on ...`. Then rerun the service normally and require success.

- [ ] **Step 7: Commit backup automation**

```bash
git add bin/backup ops/systemd/portfolio-backup.service ops/systemd/portfolio-backup.timer
git commit -m "feat: add encrypted nightly backups"
```

---

### Task 4: Implement the guarded restore command

**Files:**

- Create: `bin/restore`

**Interfaces:**

- Consumes: `bin/restore SNAPSHOT_ID`, Task 3 snapshots and environment, one initially running portfolio container, and the mounted host data directory.
- Produces: verified primary database/assets, newly prepared transient databases, retained `/var/lib/portfolio/storage.before-RESTORE_TIMESTAMP`, a restarted healthy app, and a nonzero/stopped state on unsafe failure after replacement.

- [ ] **Step 1: Create the restore command**

```bash
#!/usr/bin/env bash
# bin/restore
set -Eeuo pipefail
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
STOPPED=0
REPLACED=0

notify_failure() {
  local message=$1
  logger -t portfolio-restore -- "$message"
  if [[ -n "${OPS_SMTP_URL:-}" && -n "${OPS_SMTP_USERNAME:-}" && -n "${OPS_SMTP_PASSWORD:-}" && -n "${OPS_EMAIL_FROM:-}" && -n "${OPS_EMAIL_TO:-}" ]]; then
    printf 'From: %s\r\nTo: %s\r\nSubject: Portfolio restore failed on %s\r\n\r\n%s\r\n' \
      "$OPS_EMAIL_FROM" "$OPS_EMAIL_TO" "$(hostname -f)" "$message" |
      curl --silent --show-error --fail --ssl-reqd \
        --url "$OPS_SMTP_URL" \
        --user "$OPS_SMTP_USERNAME:$OPS_SMTP_PASSWORD" \
        --mail-from "$OPS_EMAIL_FROM" \
        --mail-rcpt "$OPS_EMAIL_TO" \
        --upload-file - >/dev/null || logger -t portfolio-restore -- "SMTP failure alert could not be sent"
  fi
}

cleanup() {
  [[ -z "$RESTORE_DIR" ]] || rm -rf -- "$RESTORE_DIR"
  [[ -z "$ENV_COPY" ]] || rm -f -- "$ENV_COPY"
}

on_error() {
  local status=$1 line=$2
  trap - ERR
  set +e
  if [[ "$STOPPED" == 1 && "$REPLACED" == 0 && -n "$APP_CONTAINER" ]]; then
    docker start "$APP_CONTAINER" >/dev/null
  elif [[ "$REPLACED" == 1 && -n "$APP_CONTAINER" ]]; then
    docker stop --time 10 "$APP_CONTAINER" >/dev/null 2>&1 || true
  fi
  notify_failure "bin/restore $SNAPSHOT_ID exited $status at line $line; replaced=$REPLACED; previous data remains at ${OLD_DIR:-not-created}; inspect before retry"
  exit "$status"
}

require_command() { command -v "$1" >/dev/null || { echo "missing command: $1" >&2; return 1; }; }
require_env() { [[ -n "${!1:-}" ]] || { echo "missing environment variable: $1" >&2; return 1; }; }

trap cleanup EXIT
trap 'on_error $? $LINENO' ERR

[[ $EUID -eq 0 ]] || { echo "bin/restore must run as root" >&2; exit 1; }
[[ $# -eq 1 && "$SNAPSHOT_ID" =~ ^[0-9a-fA-F]{8,64}$ ]] || { echo "usage: bin/restore SNAPSHOT_ID (8-64 hexadecimal characters; latest is forbidden)" >&2; exit 64; }
[[ -r "$ENV_FILE" ]] || { echo "cannot read $ENV_FILE" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a
for command_name in curl docker flock logger restic rsync sha256sum sqlite3; do require_command "$command_name"; done
for variable_name in RESTIC_REPOSITORY RESTIC_PASSWORD_FILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION; do require_env "$variable_name"; done
[[ -r "$RESTIC_PASSWORD_FILE" ]] || { echo "cannot read RESTIC_PASSWORD_FILE" >&2; exit 1; }

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another backup or restore is running" >&2; exit 75; }

EXPECTED_CONFIRMATION="RESTORE portfolio $SNAPSHOT_ID"
if [[ "${PORTFOLIO_RESTORE_CONFIRM:-}" != "$EXPECTED_CONFIRMATION" ]]; then
  printf 'This stops production and replaces %s. Type exactly: %s\n> ' "$DATA_DIR" "$EXPECTED_CONFIRMATION" >&2
  IFS= read -r confirmation
  [[ "$confirmation" == "$EXPECTED_CONFIRMATION" ]] || { echo "restore cancelled" >&2; exit 64; }
fi

mapfile -t containers < <(docker ps --filter label=service=portfolio --filter label=role=web --format '{{.ID}}')
[[ ${#containers[@]} -eq 1 ]] || { echo "expected one running portfolio web container, found ${#containers[@]}" >&2; exit 1; }
APP_CONTAINER=${containers[0]}
APP_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$APP_CONTAINER")

restic snapshots "$SNAPSHOT_ID" >/dev/null
install -d -o root -g root -m 0700 "$WORK_ROOT"
RESTORE_DIR=$(mktemp -d "$WORK_ROOT/restore.XXXXXXXX")
ENV_COPY=$(mktemp "$WORK_ROOT/container-env.XXXXXXXX")
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$APP_CONTAINER" > "$ENV_COPY"
chmod 0600 "$ENV_COPY"

docker stop --time 30 "$APP_CONTAINER" >/dev/null
STOPPED=1
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
find "$DATA_DIR" -mindepth 1 -maxdepth 1 -exec mv -t "$OLD_DIR" -- {} +
chmod 0750 "$DATA_DIR"
chown 1000:1000 "$DATA_DIR"
install -o 1000 -g 1000 -m 0640 "$RESTORE_DIR/production.sqlite3" "$DATA_DIR/production.sqlite3"
install -d -o 1000 -g 1000 -m 0750 "$DATA_DIR/active_storage"
rsync -a "$RESTORE_DIR/active_storage/" "$DATA_DIR/active_storage/"
chown -R 1000:1000 "$DATA_DIR/active_storage"
REPLACED=1

docker run --rm \
  --volumes-from "$APP_CONTAINER" \
  --env-file "$ENV_COPY" \
  --entrypoint /rails/bin/rails \
  "$APP_IMAGE" db:prepare

docker start "$APP_CONTAINER" >/dev/null
for attempt in $(seq 1 60); do
  if docker exec "$APP_CONTAINER" curl --fail --silent http://127.0.0.1/up >/dev/null 2>&1; then
    STOPPED=0
    logger -t portfolio-restore -- "restored $SNAPSHOT_ID; previous data retained at $OLD_DIR"
    printf 'restore complete: snapshot=%s previous=%s\n' "$SNAPSHOT_ID" "$OLD_DIR"
    exit 0
  fi
  sleep 1
done

echo "health check did not pass within 60 seconds" >&2
exit 1
```

Make it executable:

```bash
chmod 0755 bin/restore
```

- [ ] **Step 2: Run static guard checks**

```bash
bash -n bin/restore
shellcheck bin/restore
grep -F 'latest is forbidden' bin/restore
grep -F 'sha256sum --check SHA256SUMS' bin/restore
grep -F "PRAGMA integrity_check" bin/restore
grep -F 'production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3' bin/restore
```

Expected: all commands exit 0; ShellCheck prints nothing; each grep prints the guarding line.

- [ ] **Step 3: Verify refusal paths on the server before installing**

```bash
scp bin/restore deploy@"$DEPLOY_HOST":/tmp/portfolio-restore
ssh deploy@"$DEPLOY_HOST" 'sudo install -o root -g root -m 0755 /tmp/portfolio-restore /opt/portfolio/bin/restore
set +e
sudo /opt/portfolio/bin/restore latest
status=$?
set -e
test "$status" -eq 64
docker ps --filter label=service=portfolio --filter label=role=web --format "{{.Status}}"
'
```

Expected stderr contains:

```text
usage: bin/restore SNAPSHOT_ID (8-64 hexadecimal characters; latest is forbidden)
```

The app container remains `Up`; no data path changed.

- [ ] **Step 4: Commit guarded restore**

```bash
git add bin/restore
git commit -m "feat: add guarded portfolio restore"
```

---

### Task 5: Write the operator runbook and execute the clean-server drill

**Files:**

- Create: `docs/operations.md`

**Interfaces:**

- Consumes: Tasks 1–4 and Phase 3's owner creation/recovery Rake interface.
- Produces: repeatable setup, deploy, rollback, owner bootstrap, backup, restore, failure response, security update, and quarterly drill procedures with a measured RTO/RPO record.

- [ ] **Step 1: Write `docs/operations.md` with the following exact runbook**

````markdown
# Portfolio operations

## Invariants

- One `portfolio` web container runs on one Ubuntu host behind kamal-proxy.
- `/var/lib/portfolio/storage` is the only application bind and is owned by `1000:1000` mode `0750`.
- `production.sqlite3` and `active_storage/` are backed up. Queue, cache, and cable SQLite files are never backed up or restored.
- Nightly Restic snapshots are encrypted client-side and retain 7 daily, 4 weekly, and 6 monthly points.
- Recovery objectives: RPO at most 24 hours; RTO at most 2 hours.

## Load secrets

Load every variable named in `docs/superpowers/plans/portfolio-v4/phase-08-operations.md` from the owner's password manager. Do not source a tracked file. Verify required deploy values:

```bash
for name in DEPLOY_HOST APP_HOST RAILS_MASTER_KEY ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN SMTP_USERNAME SMTP_PASSWORD MAILER_FROM; do
  test -n "${!name:-}" || { echo "missing $name" >&2; exit 1; }
done
```

## Initial production setup

1. Point `APP_HOST` A/AAAA records at `DEPLOY_HOST` and verify `getent hosts "$APP_HOST"`.
2. Run the host provisioning command from the Phase 8 plan Task 2 Step 6.
3. Run `bin/kamal setup`.
4. Require `curl -fsS "https://$APP_HOST/up"` to exit 0.
5. Create the sole owner using the Phase 3 documented owner-creation Rake command, then sign in with password and TOTP in a private browser session.
6. Send the Task 2 SMTP check and verify receipt.
7. Install and initialize Restic using Task 3 Step 4.
8. Run `ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service'` and verify the first snapshot.

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

Expected: clean status before deploy, both suites exit 0, Kamal reports the new container healthy, HTTPS exits 0, and logs contain no boot exception. Verify one scheduled publication and one production email after changes to jobs or mail.

## Rollback

```bash
bin/kamal app containers
read -r -p "Paste the prior deployed 40-character Git version: " PREVIOUS_VERSION
[[ "$PREVIOUS_VERSION" =~ ^[0-9a-f]{40}$ ]]
bin/kamal rollback "$PREVIOUS_VERSION"
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
```

`PREVIOUS_VERSION` must be copied from `bin/kamal app containers`. Rollback changes the image only; it does not reverse migrations. If the release ran an incompatible migration, ship a corrective forward migration.

## Logs and health

```bash
bin/kamal app logs -f
curl --fail --silent --show-error --include "https://$APP_HOST/up"
ssh deploy@"$DEPLOY_HOST" 'docker ps --filter label=service=portfolio --filter label=role=web; sudo journalctl -u portfolio-backup.service -n 100 --no-pager'
```

Expected health is HTTP 200. Configure an external HTTPS uptime check for `https://$APP_HOST/up`; no agent or centralized observability service is installed.

## Manual backup

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service
sudo systemctl status portfolio-backup.service --no-pager
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio'\''
'
```

Success means `status=0/SUCCESS`, a new snapshot row, an unpaused web container, and no failure email. Any nonzero result is an incident: verify the app was unpaused, read `journalctl`, correct credentials/network/disk capacity, rerun backup, and verify a new snapshot before closing the incident.

## Production restore

1. Select an explicit hexadecimal ID using `restic snapshots --tag portfolio`; never restore `latest`.
2. Record incident start UTC and the selected snapshot UTC. Abort if snapshot age exceeds 24 hours unless accepting an explicitly documented RPO breach.
3. Confirm at least twice the latest snapshot size is free under `/var/lib/portfolio` because the previous data directory is retained.
4. Run:

```bash
ssh -t deploy@"$DEPLOY_HOST" "sudo /opt/portfolio/bin/restore $SNAPSHOT_ID"
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
bin/kamal app exec 'bin/rails runner '\''puts({projects: Project.count, posts: Post.count, blobs: ActiveStorage::Blob.count, contacts: ContactMessage.count}.inspect)'\'''
```

5. Sign in, open one project image and each localized résumé PDF, submit a contact message, and verify scheduled publishing can run.
6. Keep the printed `storage.before-*` directory until owner acceptance. Then validate and remove that one exact printed path; never use a glob:

```bash
[[ "$VERIFIED_OLD_DIR" =~ ^/var/lib/portfolio/storage\.before-[0-9]{8}T[0-9]{6}Z$ ]]
sudo rm -rf -- "$VERIFIED_OLD_DIR"
```

7. Record restore end UTC, snapshot age, elapsed minutes, SQLite result, asset result, smoke result, operator, and incident link.

On a restore error after replacement, the script deliberately leaves the app stopped and retains the old data directory. Read the emailed/journaled line, inspect both directories, and either retry the same verified snapshot or empty the stable bind directory and move the saved contents back while the container remains stopped; never rename the bind directory itself.

## Quarterly clean-server restore drill

Run before launch, every quarter, and after every backup-process change.

1. Create a disposable clean AMD64 Ubuntu 24.04 host. Set `DRILL_HOST` to its address, point `DRILL_APP_HOST` DNS to it, and verify DNS.
2. Create a known database-plus-asset probe in production:

```bash
DRILL_TOKEN="restore-drill-$(date -u +%Y%m%dT%H%M%SZ)"
RESULT="$(bin/kamal app exec --reuse "bin/rails runner 'blob=ActiveStorage::Blob.create_and_upload!(io: StringIO.new(\"$DRILL_TOKEN\"), filename: \"restore-drill.txt\", content_type: \"text/plain\"); puts \"#{blob.id}:#{blob.checksum}\"'" | tail -n 1)"
printf '%s\n' "$RESULT"
```

Save `DRILL_TOKEN` and the final `BLOB_ID:CHECKSUM` line in the drill record.

3. Run a production backup and capture its explicit ID:

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl start portfolio-backup.service'
SNAPSHOT_ID="$(ssh deploy@"$DEPLOY_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio --latest 1 --json'\''' | ruby -rjson -e 'puts JSON.parse(STDIN.read).last.fetch("id")')"
START_EPOCH="$(date +%s)"
```

4. In a fresh shell, set `DEPLOY_HOST="$DRILL_HOST"` and `APP_HOST="$DRILL_APP_HOST"`, provision the server, and run `bin/kamal setup`. This creates an empty mounted directory and one labeled running container.
5. Install `/etc/portfolio/backup.env`, `/etc/portfolio/restic-password`, and `/opt/portfolio/bin/restore` on the drill host using Task 3 Step 4 and Task 4 Step 3. Do not enable its backup timer.
6. Restore non-interactively with an exact confirmation bound to the selected ID:

```bash
ssh deploy@"$DRILL_HOST" "sudo PORTFOLIO_RESTORE_CONFIRM='RESTORE portfolio $SNAPSHOT_ID' /opt/portfolio/bin/restore '$SNAPSHOT_ID'"
```

Expected output includes every manifest line ending `OK` and:

```text
restore complete: snapshot=
```

7. Prove database integrity, exact asset bytes, HTTPS, and fresh transient databases:

```bash
curl --fail --silent --show-error "https://$DRILL_APP_HOST/up" >/dev/null
ssh deploy@"$DRILL_HOST" 'sqlite3 /var/lib/portfolio/storage/production.sqlite3 "PRAGMA integrity_check;"; find /var/lib/portfolio/storage/active_storage -type f -print0 | sort -z | xargs -0 sha256sum >/tmp/drill-assets.sha256; test -s /tmp/drill-assets.sha256; for db in production_queue.sqlite3 production_cache.sqlite3 production_cable.sqlite3; do test -f "/var/lib/portfolio/storage/$db"; done'
DEPLOY_HOST="$DRILL_HOST" APP_HOST="$DRILL_APP_HOST" bin/kamal app exec --reuse "bin/rails runner 'blob=ActiveStorage::Blob.find(${RESULT%%:*}); abort unless blob.checksum == \"${RESULT#*:}\"; abort unless blob.download == \"$DRILL_TOKEN\"; puts \"asset verified\"'"
END_EPOCH="$(date +%s)"
printf 'RTO minutes: %d\n' "$(( (END_EPOCH - START_EPOCH + 59) / 60 ))"
```

Expected output includes:

```text
ok
asset verified
```

RTO must be 120 minutes or less. Snapshot creation time must be 24 hours old or less.

8. Check Restic repository data independently:

```bash
ssh deploy@"$DRILL_HOST" 'sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic check --read-data-subset=100%'\'''
```

Expected ending: `no errors were found`.

9. Record the date, snapshot ID/time, operator, RPO age, RTO minutes, `integrity_check=ok`, asset checksum/download result, HTTPS result, and Restic check result in the private operations record. Delete the drill server and drill DNS record. Remove the probe blob from production only after the drill record is complete:

```bash
bin/kamal app exec --reuse "bin/rails runner 'ActiveStorage::Blob.find(${RESULT%%:*}).purge; puts \"probe removed\"'"
```

## Security and capacity maintenance

Monthly:

```bash
bundle outdated
bin/bundler-audit check --update
ssh deploy@"$DEPLOY_HOST" 'sudo apt-get update && sudo apt-get -y upgrade && sudo reboot'
sleep 60
curl --fail --silent --show-error "https://$APP_HOST/up" >/dev/null
ssh deploy@"$DEPLOY_HOST" 'df -h /var/lib/portfolio; sudo systemctl status portfolio-backup.timer --no-pager'
```

Apply critical updates sooner. After reboot, require health, one running web container, an active timer, and adequate local space. Add capacity before either the data directory or backup staging can exhaust disk.
````

If Phase 3 chose a concrete owner Rake task name, replace only the prose reference in Initial production setup with that exact already-implemented command; do not invent a second owner bootstrap path.

- [ ] **Step 2: Execute the pre-launch clean-server drill**

Follow the runbook without skipping its failure checks. Capture private evidence outside Git because it contains host names, snapshot IDs, account counts, and potentially identifying file names.

Expected acceptance record:

```text
integrity_check=ok
asset_download=verified
https_health=200
restic_check=no_errors
rpo_hours<=24
rto_minutes<=120
```

- [ ] **Step 3: Verify timer recovery and retention visibility**

```bash
ssh deploy@"$DEPLOY_HOST" 'sudo systemctl is-enabled portfolio-backup.timer
sudo systemctl is-active portfolio-backup.timer
sudo systemctl list-timers portfolio-backup.timer --no-pager
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic snapshots --tag portfolio'\''
'
```

Expected first two lines:

```text
enabled
active
```

The snapshot table has at least the pre-launch and drill snapshots. Retention converges to 7 daily, 4 weekly, and 6 monthly after enough calendar periods; do not fabricate historical snapshots to test aging.

- [ ] **Step 4: Commit the runbook**

```bash
git add docs/operations.md
git commit -m "docs: add portfolio operations runbook"
```

---

### Task 6: Phase acceptance and release tag

**Files:**

- Verify only; no source changes expected.

**Interfaces:**

- Consumes: all Phase 8 tasks.
- Produces: accepted `portfolio-v4-phase-8` tag only after every automated and manual gate passes.

- [ ] **Step 1: Run repository checks**

```bash
bash -n bin/backup bin/restore
shellcheck bin/backup bin/restore
bin/rails test
bin/rails test:system
docker build --platform linux/amd64 -t portfolio:phase-8-acceptance .
git status --short
```

Expected: every command exits 0 and Git status is empty.

- [ ] **Step 2: Run production acceptance checks**

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
sudo systemctl is-active --quiet portfolio-backup.timer
sudo bash -c '\''set -a; source /etc/portfolio/backup.env; set +a; restic check --read-data-subset=100%'\''
'
```

Expected: HTTP 200, exactly one web container, correct bind ownership, SQLite `ok`, active timer, and Restic ending `no errors were found`.

- [ ] **Step 3: Manually confirm release-only evidence**

Require all of these before tagging:

- Kamal deploy and one tested rollback completed without changing database or uploaded assets.
- Host restart preserved primary data and uploads.
- Production SMTP message arrived.
- Solid Queue processed an email and an overdue scheduled publication after restart.
- A successful backup contains primary SQLite plus all Active Storage objects and excludes queue/cache/cable databases.
- The forced backup failure resumed the app and delivered an operational email.
- The clean-server drill passed manifest checksums, `PRAGMA integrity_check`, exact probe download, HTTPS smoke, and full Restic data verification.
- Recorded RPO is at most 24 hours and recorded RTO is at most 120 minutes.
- Rails master key, SMTP secrets, Restic password, S3 credentials, host addresses, and private drill evidence are absent from Git.

- [ ] **Step 4: Tag the accepted phase**

```bash
git status --short
git tag -a portfolio-v4-phase-8 -m "Accept portfolio v4 phase 8 operations"
git show --stat --oneline portfolio-v4-phase-8
```

Expected: clean status and an annotated tag pointing at the four Phase 8 commits. Do not tag if any preceding gate is incomplete.

## Risks and rollback boundaries

- **SQLite/asset skew:** copying a live asset tree independently could mismatch metadata. `docker pause` is mandatory around both `.backup` and `rsync`; the error trap must be tested to unpause.
- **Bind ownership:** Kamal does not fix host-bind ownership. Numeric `1000:1000` is an acceptance gate before and after restore.
- **TLS redirect loop:** kamal-proxy terminates TLS, so `config.assume_ssl = true` and `config.force_ssl = true` stay paired.
- **Transient work duplication:** queue/cache/cable databases are intentionally excluded and recreated. Durable contact delivery state and publication schedule state must remain in the primary database, as established in Phases 5–6.
- **Restore data loss:** an explicit hexadecimal snapshot ID and exact typed confirmation are required. The old contents directory is retained until manual acceptance; no wildcard deletion appears in the runbook.
- **Restore boot failure:** after replacement, failure leaves the app stopped rather than serving uncertain data. The old directory and downloaded-snapshot diagnostics remain available.
- **Repository corruption or credential loss:** nightly `restic check --read-data-subset=100%`, quarterly clean-server restore, and separately stored Restic/S3 credentials are all required; a successful upload alone is not proof of recovery.
- **Single-server downtime:** pause, restore, and host updates cause downtime by design. This is within the approved topology; add replication or a second app host only if measured availability requirements change.
- **Forward-only migrations:** image rollback never rolls the database backward. Correct incompatible migrations forward.
