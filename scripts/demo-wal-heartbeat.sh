#!/usr/bin/env bash
set -Eeuo pipefail

# Demonstrate that quiet captured tables let a logical slot retain WAL, and that
# heartbeat.action.query advances the slot while pgbench traffic stays outside
# the publication.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands awk docker curl jq

connector_name=playground-outbox-connector
connect_url="http://127.0.0.1:${CONNECT_HOST_PORT}/connectors/${connector_name}"
noise_db=noise
load_seconds=${WAL_DEMO_LOAD_SECONDS:-45}
min_growth_bytes=${WAL_DEMO_MIN_GROWTH_BYTES:-5242880}
heartbeat_action_query="INSERT INTO app.debezium_heartbeat (id, updated_at, connector_name) VALUES (1, clock_timestamp(), 'playground-outbox-connector') ON CONFLICT (id) DO UPDATE SET updated_at = EXCLUDED.updated_at, connector_name = EXCLUDED.connector_name"

demo_failed() {
  local exit_code=$?
  trap - ERR
  printf 'WAL heartbeat demo failed with exit code %s.\n' "$exit_code" >&2
  restore_connector_config || true
  diagnostics
  exit "$exit_code"
}
trap demo_failed ERR

sql_db() {
  local database=$1
  shift
  local runner
  runner=$(first_running_postgres)
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" psql -X -v ON_ERROR_STOP=1 \
    -h haproxy -p 5432 -U postgres -d "$database" "$@"
}

connector_running() {
  local status
  status=$(curl --fail --silent "$connect_url/status" 2>/dev/null || true)
  [[ "$status" == *'"connector":{"state":"RUNNING"'* ]] \
    && [[ "$status" == *'"tasks":[{"id":0,"state":"RUNNING"'* ]]
}

wait_for_connector() {
  wait_until 120 'connector RUNNING' connector_running
}

put_connector_config() {
  local config_file=$1 http_code
  curl --fail --silent --show-error \
    --request PUT \
    --header 'Content-Type: application/json' \
    --data-binary "@$config_file" \
    "$connect_url/config" >/dev/null
  # Config PUT may already restart tasks; 409 means a restart is in progress.
  http_code=$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --request POST \
    "$connect_url/restart?includeTasks=true" || true)
  if [[ "$http_code" != 204 && "$http_code" != 200 && "$http_code" != 409 ]]; then
    printf 'Unexpected connector restart HTTP status: %s\n' "$http_code" >&2
    return 1
  fi
  wait_for_connector
}

save_connector_config() {
  curl --fail --silent --show-error "$connect_url/config"
}

restore_connector_config() {
  if [[ -z "${original_config:-}" ]]; then
    return 0
  fi
  printf '%s\n' "$original_config" >"$restore_config_file"
  put_connector_config "$restore_config_file"
}

slot_metrics_json() {
  sql_via_haproxy -Atc "
    SELECT json_build_object(
      'slot_name', slot_name,
      'active', active,
      'wal_status', wal_status,
      'restart_lsn', restart_lsn::text,
      'confirmed_flush_lsn', confirmed_flush_lsn::text,
      'current_lsn', pg_current_wal_lsn()::text,
      'retained_bytes', pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn),
      'retained_pretty', pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
    )
    FROM pg_replication_slots
    WHERE slot_name = 'playground_slot';
  "
}

print_slot_metrics() {
  local label=$1 metrics=$2
  jq -r --arg label "$label" '
    "\($label): active=\(.active) wal_status=\(.wal_status)"
    + " confirmed_flush_lsn=\(.confirmed_flush_lsn)"
    + " restart_lsn=\(.restart_lsn)"
    + " current_lsn=\(.current_lsn)"
    + " retained_wal=\(.retained_pretty) (\(.retained_bytes) bytes)"
  ' <<<"$metrics"
}

ensure_noise_database() {
  if [[ $(sql_db postgres -Atc "SELECT count(*) FROM pg_database WHERE datname = '${noise_db}'") != 1 ]]; then
    sql_db postgres -c "CREATE DATABASE ${noise_db}"
  fi

  local runner
  runner=$(first_running_postgres)
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" pgbench -h haproxy -p 5432 -U postgres -i -s 2 "$noise_db" >/dev/null
}

stack_has_running_services() {
  compose ps --status running --services | grep -q .
}

run_pgbench_noise() {
  local seconds=$1
  local runner
  runner=$(first_running_postgres)
  printf 'Generating WAL with pgbench against database %s for %ss (tables outside the publication)...\n' \
    "$noise_db" "$seconds"
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" pgbench -h haproxy -p 5432 -U postgres \
    -T "$seconds" -c 4 -j 2 -P 15 "$noise_db"
}

connector_has_action_query() {
  local config
  config=$(save_connector_config)
  jq -e '."heartbeat.action.query" | type == "string" and length > 0' <<<"$config" >/dev/null
}

disable_source_heartbeat() {
  printf 'Removing heartbeat.action.query from %s (keeping heartbeat.interval.ms)...\n' \
    "$connector_name"
  save_connector_config \
    | jq 'del(."heartbeat.action.query")' >"$phase_config_file"
  put_connector_config "$phase_config_file"
  if connector_has_action_query; then
    printf 'heartbeat.action.query is still present after update.\n' >&2
    return 1
  fi
}

enable_source_heartbeat() {
  printf 'Restoring heartbeat.action.query on %s...\n' "$connector_name"
  save_connector_config \
    | jq --arg q "$heartbeat_action_query" \
      '."heartbeat.interval.ms" = (."heartbeat.interval.ms" // "10000")
       | ."heartbeat.action.query" = $q
       | ."topic.heartbeat.prefix" = (."topic.heartbeat.prefix" // "playground.heartbeat")' \
      >"$phase_config_file"
  put_connector_config "$phase_config_file"
  if ! connector_has_action_query; then
    printf 'heartbeat.action.query missing after restore.\n' >&2
    return 1
  fi
}

heartbeat_row_updated_since() {
  local prior_updated_at=$1
  local current
  current=$(sql_via_haproxy -Atc \
    "SELECT updated_at::text FROM app.debezium_heartbeat WHERE id = 1;")
  [[ "$current" != "$prior_updated_at" ]]
}

wait_for_heartbeat_row_change() {
  local prior_updated_at
  prior_updated_at=$(sql_via_haproxy -Atc \
    "SELECT updated_at::text FROM app.debezium_heartbeat WHERE id = 1;")
  wait_until 60 'heartbeat row update' heartbeat_row_updated_since "$prior_updated_at"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
phase_config_file=$tmp_dir/phase-config.json
restore_config_file=$tmp_dir/restore-config.json

printf '=== WAL heartbeat demo ===\n'
printf 'Traffic will hit database %s only. Captured tables stay quiet.\n\n' "$noise_db"

wait_until 60 'Compose stack ready' stack_has_running_services
wait_for_initializers 180 database-init connector-init
wait_for_connector

original_config=$(save_connector_config)
printf '%s\n' "$original_config" >"$restore_config_file"

ensure_noise_database

printf '\n=== Phase 1: source heartbeat disabled ===\n'
disable_source_heartbeat
# Let any in-flight heartbeat settle, then sample a quiet baseline.
sleep 12
before_no_hb=$(slot_metrics_json)
print_slot_metrics 'baseline' "$before_no_hb"
confirmed_before=$(jq -r '.confirmed_flush_lsn' <<<"$before_no_hb")
retained_before=$(jq -r '.retained_bytes' <<<"$before_no_hb")

run_pgbench_noise "$load_seconds"

after_no_hb=$(slot_metrics_json)
print_slot_metrics 'after pgbench' "$after_no_hb"
confirmed_after=$(jq -r '.confirmed_flush_lsn' <<<"$after_no_hb")
retained_after=$(jq -r '.retained_bytes' <<<"$after_no_hb")
growth_no_hb=$((retained_after - retained_before))

printf 'confirmed_flush_lsn before=%s after=%s\n' "$confirmed_before" "$confirmed_after"
printf 'retained_bytes growth without source heartbeat: %s bytes\n' "$growth_no_hb"

if [[ "$confirmed_after" != "$confirmed_before" ]]; then
  printf 'Expected confirmed_flush_lsn to stall without heartbeat.action.query.\n' >&2
  exit 1
fi
if (( growth_no_hb < min_growth_bytes )); then
  printf 'Expected retained WAL to grow by at least %s bytes; saw %s.\n' \
    "$min_growth_bytes" "$growth_no_hb" >&2
  exit 1
fi
printf 'Phase 1 OK: connector RUNNING, slot stalled, retained WAL grew.\n'

printf '\n=== Phase 2: source heartbeat enabled ===\n'
enable_source_heartbeat
wait_for_heartbeat_row_change
before_hb=$(slot_metrics_json)
print_slot_metrics 'baseline' "$before_hb"
confirmed_hb_before=$(jq -r '.confirmed_flush_lsn' <<<"$before_hb")
retained_hb_before=$(jq -r '.retained_bytes' <<<"$before_hb")
heartbeat_at=$(sql_via_haproxy -Atc \
  "SELECT updated_at::text FROM app.debezium_heartbeat WHERE id = 1;")

run_pgbench_noise "$load_seconds"
wait_for_heartbeat_row_change

after_hb=$(slot_metrics_json)
print_slot_metrics 'after pgbench + heartbeats' "$after_hb"
confirmed_hb_after=$(jq -r '.confirmed_flush_lsn' <<<"$after_hb")
retained_hb_after=$(jq -r '.retained_bytes' <<<"$after_hb")
growth_hb=$((retained_hb_after - retained_hb_before))
heartbeat_after=$(sql_via_haproxy -Atc \
  "SELECT updated_at::text FROM app.debezium_heartbeat WHERE id = 1;")

printf 'confirmed_flush_lsn before=%s after=%s\n' "$confirmed_hb_before" "$confirmed_hb_after"
printf 'heartbeat.updated_at before=%s after=%s\n' "$heartbeat_at" "$heartbeat_after"
printf 'retained_bytes delta with source heartbeat: %s bytes\n' "$growth_hb"

if [[ "$confirmed_hb_after" == "$confirmed_hb_before" ]]; then
  printf 'Expected confirmed_flush_lsn to advance after enabling heartbeat.action.query.\n' >&2
  exit 1
fi
if [[ "$heartbeat_after" == "$heartbeat_at" ]]; then
  printf 'Expected app.debezium_heartbeat.updated_at to change.\n' >&2
  exit 1
fi
# With a source heartbeat the slot should not retain nearly as much of the load.
# Allow some decoding lag, but require a clear improvement versus phase 1 growth.
if (( growth_hb * 2 >= growth_no_hb )); then
  printf 'Expected retained WAL growth with heartbeat (%s) to be well below phase 1 (%s).\n' \
    "$growth_hb" "$growth_no_hb" >&2
  exit 1
fi
printf 'Phase 2 OK: heartbeat row moved, confirmed_flush_lsn advanced, retained WAL stayed bounded.\n'

printf '\n=== Restoring original connector configuration ===\n'
restore_connector_config
printf '\nDemo complete.\n'
printf 'Without heartbeat.action.query, quiet captured tables left retained WAL growing'
printf ' while confirmed_flush_lsn stayed at %s.\n' "$confirmed_before"
printf 'With heartbeat.action.query, the same off-publication pgbench load advanced the slot'
printf ' and kept retained WAL from accumulating without bound.\n'
