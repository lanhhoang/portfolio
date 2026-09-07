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
