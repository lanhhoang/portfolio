#!/usr/bin/env bash
set -euo pipefail

if [[ "${IN_CONTAINER:-}" != 1 ]]; then
  if command -v podman >/dev/null; then
    engine=podman
  elif command -v docker >/dev/null; then
    engine=docker
  else
    echo "Podman or Docker is required" >&2
    exit 1
  fi

  root=$(cd "$(dirname "$0")/../.." && pwd)
  exec "$engine" run --rm --user 0 \
    -e IN_CONTAINER=1 \
    -v "$root:/repo:ro" \
    docker.io/library/ruby:4.0.6-slim \
    bash /repo/test/operations/backup_restore_safety_test.sh
fi

fakebin=$(mktemp -d)
trap 'rm -rf "$fakebin"' EXIT

cat > "$fakebin/docker" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
state_file=/tmp/docker-state
case "$1" in
  ps)
    if [[ "$*" == *" -a "* || "$(cat "$state_file")" != stopped ]]; then
      printf 'portfolio-container\n'
    fi
    ;;
  pause)
    printf 'paused\n' > "$state_file"
    printf 'pause\n' >> /tmp/docker-actions
    ;;
  unpause)
    printf 'running\n' > "$state_file"
    printf 'unpause\n' >> /tmp/docker-actions
    ;;
  inspect)
    case "$*" in
      *State.Paused*) [[ "$(cat "$state_file")" == paused ]] && printf 'true\n' || printf 'false\n' ;;
      *State.Running*) [[ "$(cat "$state_file")" == running ]] && printf 'true\n' || printf 'false\n' ;;
      *Config.Image*) printf 'portfolio:test\n' ;;
      *Config.Env*) printf 'RAILS_ENV=production\n' ;;
      *) echo "unexpected docker inspect: $*" >&2; exit 1 ;;
    esac
    ;;
  stop)
    printf 'stopped\n' > "$state_file"
    printf 'stop\n' >> /tmp/docker-actions
    ;;
  start)
    printf 'running\n' > "$state_file"
    printf 'start\n' >> /tmp/docker-actions
    ;;
  run|exec) ;;
  *) echo "unexpected docker command: $*" >&2; exit 1 ;;
esac
SCRIPT

cat > "$fakebin/restic" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  snapshots|forget|check) ;;
  backup)
    rm -rf /tmp/snapshot
    mkdir /tmp/snapshot
    cp -a . /tmp/snapshot/
    ;;
  restore)
    target=$4
    mkdir -p "$target/active_storage"
    printf 'restored database\n' > "$target/production.sqlite3"
    printf 'restored asset\n' > "$target/active_storage/file"
    (
      cd "$target"
      find production.sqlite3 active_storage -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
    )
    ;;
  *) echo "unexpected restic command: $*" >&2; exit 1 ;;
esac
SCRIPT

cat > "$fakebin/rsync" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "${FAIL_RSYNC:-}" != 1 ]] || exit 42
paths=()
for argument in "$@"; do
  [[ "$argument" == -* ]] || paths+=("$argument")
done
cp -a "${paths[0]}/." "${paths[1]}/"
SCRIPT

cat > "$fakebin/sqlite3" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *".backup '"* ]]; then
  destination=$(sed -n "s/.*\.backup '\([^']*\)'.*/\1/p" <<< "$*")
  cp "$1" "$destination"
elif [[ "$*" == *"PRAGMA integrity_check"* ]]; then
  printf 'ok\n'
else
  echo "unexpected sqlite3 command: $*" >&2
  exit 1
fi
SCRIPT

for command_name in curl flock logger; do
  cat > "$fakebin/$command_name" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
done
chmod 0755 "$fakebin"/*

rm -rf /var/lib/portfolio /etc/portfolio /tmp/snapshot /tmp/docker-actions /tmp/docker-state
mkdir -p /var/lib/portfolio/storage /etc/portfolio
printf 'running\n' > /tmp/docker-state
printf 'database\n' > /var/lib/portfolio/storage/production.sqlite3
printf 'password\n' > /etc/portfolio/restic-password
cat > /etc/portfolio/backup.env <<'ENV'
RESTIC_REPOSITORY=s3:s3.example.test/portfolio
RESTIC_PASSWORD_FILE=/etc/portfolio/restic-password
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=test
OPS_SMTP_URL=smtp://smtp.example.test:587
OPS_SMTP_USERNAME=test
OPS_SMTP_PASSWORD=test
OPS_EMAIL_FROM=ops@example.test
OPS_EMAIL_TO=owner@example.test
ENV

PATH="$fakebin:$PATH" /repo/bin/backup

test -d /var/lib/portfolio/storage/active_storage
test -f /tmp/snapshot/production.sqlite3
test -d /tmp/snapshot/active_storage
grep -Fqx pause /tmp/docker-actions
grep -Fqx unpause /tmp/docker-actions
printf 'Empty Active Storage backup verified\n'

rm -rf /var/lib/portfolio /tmp/docker-actions
mkdir -p /var/lib/portfolio/storage/active_storage
printf 'running\n' > /tmp/docker-state
printf 'database\n' > /var/lib/portfolio/storage/production.sqlite3
set +e
FAIL_RSYNC=1 PATH="$fakebin:$PATH" /repo/bin/backup
status=$?
set -e
test "$status" -ne 0
test "$(cat /tmp/docker-state)" = running
test "$(tail -n 1 /tmp/docker-actions)" = unpause
printf 'Failed backup resumes writes\n'

rm -rf /var/lib/portfolio /tmp/docker-actions
mkdir -p /var/lib/portfolio/storage/active_storage
printf 'running\n' > /tmp/docker-state
printf 'original database\n' > /var/lib/portfolio/storage/production.sqlite3
printf 'original asset\n' > /var/lib/portfolio/storage/active_storage/file

set +e
FAIL_RSYNC=1 \
PORTFOLIO_RESTORE_CONFIRM='RESTORE portfolio abcdef12' \
PATH="$fakebin:$PATH" \
  /repo/bin/restore abcdef12
status=$?
set -e

test "$status" -ne 0
if grep -Fqx start /tmp/docker-actions; then
  echo "restore restarted the app after replacement had begun" >&2
  exit 1
fi
test "$(tail -n 1 /tmp/docker-actions)" = stop
printf 'Partial replacement remains stopped\n'

rm -rf /var/lib/portfolio /tmp/docker-actions
mkdir -p /var/lib/portfolio/storage/active_storage
printf 'running\n' > /tmp/docker-state
printf 'original database\n' > /var/lib/portfolio/storage/production.sqlite3
printf 'original asset\n' > /var/lib/portfolio/storage/active_storage/file

PORTFOLIO_RESTORE_CONFIRM='RESTORE portfolio abcdef12' \
PATH="$fakebin:$PATH" \
  /repo/bin/restore abcdef12

test "$(cat /tmp/docker-state)" = running
test "$(cat /var/lib/portfolio/storage/production.sqlite3)" = 'restored database'
test "$(cat /var/lib/portfolio/storage/active_storage/file)" = 'restored asset'
old_dir=$(find /var/lib/portfolio -maxdepth 1 -type d -name 'storage.before-*')
test -n "$old_dir"
test "$(cat "$old_dir/production.sqlite3")" = 'original database'
printf 'Successful restore preserves old data and resumes service\n'
