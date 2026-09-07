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

Run operational script checks with SQLite and a local Podman or Docker engine:

```bash
test/operations/sqlite_backup_test.sh
test/operations/backup_restore_safety_test.sh
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
