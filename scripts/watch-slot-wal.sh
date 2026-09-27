#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials

while true; do
  clear 2>/dev/null || true
  printf '\033[1m2 · playground_slot / retained WAL\033[0m\n'
  printf 'Updated: %s\n\n' "$(date -u +'%H:%M:%S UTC')"
  sql_via_haproxy --command "
    SELECT
      slot_name,
      active,
      wal_status,
      restart_lsn,
      confirmed_flush_lsn,
      pg_current_wal_lsn() AS current_lsn,
      pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
      ) AS retained_wal,
      pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS retained_bytes
    FROM pg_replication_slots
    WHERE slot_name = 'playground_slot';
  " || printf '(waiting for PostgreSQL…)\n'
  sleep 2
done
