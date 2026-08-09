#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker curl jq

former_primary=$(discover_primary)
printf 'Stopping current primary %s...\n' "$former_primary"
compose stop "$former_primary"

different_primary_ready() {
  local candidate
  candidate=$(discover_primary 2>/dev/null || true)
  [[ -n "$candidate" && "$candidate" != "$former_primary" ]]
}

if ! wait_until 60 'a different PostgreSQL primary' different_primary_ready; then
  diagnostics
  exit 1
fi

new_primary=$(discover_primary)
printf 'Promoted %s. Restarting %s...\n' "$new_primary" "$former_primary"
compose start "$former_primary"

former_primary_is_streaming_replica() {
  local port recovery receiver
  port=$(patroni_port "$former_primary")
  curl --fail --silent "http://127.0.0.1:${port}/replica" >/dev/null 2>&1 || return 1
  recovery=$(compose exec -T "$former_primary" psql -XAt -U postgres -d postgres \
    -c 'SELECT pg_is_in_recovery();' 2>/dev/null || true)
  receiver=$(compose exec -T "$former_primary" psql -XAt -U postgres -d postgres \
    -c "SELECT count(*) FROM pg_stat_wal_receiver WHERE status = 'streaming';" 2>/dev/null || true)
  [[ "$recovery" == t && "$receiver" == 1 ]]
}

if ! wait_until 120 "$former_primary to rejoin as a streaming replica" former_primary_is_streaming_replica; then
  diagnostics
  exit 1
fi

printf 'Failover complete: %s -> %s; %s rejoined as a streaming replica.\n' \
  "$former_primary" "$new_primary" "$former_primary"
