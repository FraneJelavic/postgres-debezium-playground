#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials

while true; do
  clear 2>/dev/null || true
  printf '\033[1m3 · app.debezium_heartbeat\033[0m\n'
  printf 'Updated: %s\n\n' "$(date -u +'%H:%M:%S UTC')"
  sql_via_haproxy --command "
    SELECT
      id,
      connector_name,
      updated_at,
      date_trunc('second', clock_timestamp() - updated_at) AS age
    FROM app.debezium_heartbeat
    WHERE id = 1;
  " || printf '(waiting for PostgreSQL…)\n'
  printf '\n\033[2mWhen heartbeat.action.query is removed, age grows.\n'
  printf 'When it is restored, updated_at moves about every 10s.\033[0m\n'
  sleep 1
done
