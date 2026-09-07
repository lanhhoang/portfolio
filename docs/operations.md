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
