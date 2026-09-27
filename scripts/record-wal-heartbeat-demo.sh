#!/usr/bin/env bash
set -Eeuo pipefail

# Drive a paced 3-pane WAL heartbeat demo suitable for screen recording.
# Pane titles are set by the caller; this script runs in the operations pane.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker curl jq

connector_name=playground-outbox-connector
connect_url="http://127.0.0.1:${CONNECT_HOST_PORT}/connectors/${connector_name}"
noise_db=noise
load_seconds=${WAL_DEMO_LOAD_SECONDS:-20}
heartbeat_action_query="INSERT INTO app.debezium_heartbeat (id, updated_at, connector_name) VALUES (1, clock_timestamp(), 'playground-outbox-connector') ON CONFLICT (id) DO UPDATE SET updated_at = EXCLUDED.updated_at, connector_name = EXCLUDED.connector_name"

say() {
  printf '\n\033[1;36m==> %s\033[0m\n' "$*"
  sleep 1
}

pause() {
  local seconds=${1:-3}
  printf '\033[2m… %ss …\033[0m\n' "$seconds"
  sleep "$seconds"
}

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

put_connector_config() {
  local config_file=$1 http_code
  curl --fail --silent --show-error \
    --request PUT \
    --header 'Content-Type: application/json' \
    --data-binary "@$config_file" \
    "$connect_url/config" >/dev/null
  http_code=$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --request POST \
    "$connect_url/restart?includeTasks=true" || true)
  case "$http_code" in
    200|202|204|409) ;;
    *)
      printf 'Unexpected connector restart HTTP status: %s\n' "$http_code" >&2
      return 1
      ;;
  esac
  wait_until 120 'connector RUNNING' connector_running
}

ensure_noise_database() {
  if [[ $(sql_db postgres -Atc "SELECT count(*) FROM pg_database WHERE datname = '${noise_db}'") != 1 ]]; then
    sql_db postgres -c "CREATE DATABASE ${noise_db}"
  fi
  local runner
  runner=$(first_running_postgres)
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" pgbench -h haproxy -p 5432 -U postgres -i -q -s 2 "$noise_db" >/dev/null
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
phase_config_file=$tmp_dir/phase-config.json
original_config=$(curl --fail --silent --show-error "$connect_url/config")
printf '%s\n' "$original_config" >"$tmp_dir/original.json"

clear 2>/dev/null || true
printf '\033[1mWAL heartbeat demo — operations pane\033[0m\n'
printf 'Left/top: this pane. Middle: slot/WAL. Right: heartbeat row.\n'
ensure_noise_database
wait_until 60 'connector RUNNING' connector_running

say "Phase 1 — remove heartbeat.action.query (keep heartbeat.interval.ms)"
curl --fail --silent --show-error "$connect_url/config" \
  | jq 'del(."heartbeat.action.query")' >"$phase_config_file"
jq '{
  "heartbeat.interval.ms": ."heartbeat.interval.ms",
  "heartbeat.action.query": (."heartbeat.action.query" // null)
}' "$phase_config_file"
put_connector_config "$phase_config_file"
printf 'Source heartbeat disabled. Watch panes: LSN should stall; heartbeat.updated_at should freeze.\n'
pause 8

say "Generate WAL with pgbench against database '${noise_db}' (${load_seconds}s, outside publication)"
runner=$(first_running_postgres)
compose exec -T \
  --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
  "$runner" pgbench -h haproxy -p 5432 -U postgres \
  -T "$load_seconds" -c 4 -j 2 -P 5 "$noise_db"
printf 'pgbench finished. Retained WAL should have grown; confirmed_flush_lsn unchanged.\n'
pause 10

say "Phase 2 — restore heartbeat.action.query"
curl --fail --silent --show-error "$connect_url/config" \
  | jq --arg q "$heartbeat_action_query" \
    '."heartbeat.interval.ms" = (."heartbeat.interval.ms" // "10000")
     | ."heartbeat.action.query" = $q
     | ."topic.heartbeat.prefix" = (."topic.heartbeat.prefix" // "playground.heartbeat")' \
    >"$phase_config_file"
jq '{
  "heartbeat.interval.ms": ."heartbeat.interval.ms",
  "heartbeat.action.query": ."heartbeat.action.query"
}' "$phase_config_file"
put_connector_config "$phase_config_file"
printf 'Source heartbeat restored. Watch panes: heartbeat.updated_at should start moving again.\n'
pause 12

say "Repeat the same off-publication pgbench load (${load_seconds}s)"
compose exec -T \
  --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
  "$runner" pgbench -h haproxy -p 5432 -U postgres \
  -T "$load_seconds" -c 4 -j 2 -P 5 "$noise_db"
printf 'pgbench finished. confirmed_flush_lsn should advance; retained WAL should reclaim while idle.\n'
pause 25

say "Restore original connector configuration"
put_connector_config "$tmp_dir/original.json"
printf '\n\033[1;32mDemo complete.\033[0m Watch panes should show a moving heartbeat and low retained WAL.\n'
pause 8
