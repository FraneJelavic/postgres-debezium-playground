#!/usr/bin/env bash

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
credentials_file="$root_dir/.state/credentials.env"

load_credentials() {
  local requested_project_name=${COMPOSE_PROJECT_NAME-}
  if [[ ! -f "$credentials_file" ]]; then
    printf 'Credentials are missing. Run make init first.\n' >&2
    return 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$credentials_file"
  set +a
  if [[ -n "$requested_project_name" ]]; then
    COMPOSE_PROJECT_NAME=$requested_project_name
    export COMPOSE_PROJECT_NAME
  fi
  : "${COMPOSE_PROJECT_NAME:=postgres-debezium-playground}"
}

require_commands() {
  local missing=0 command_name
  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'Missing required command: %s\n' "$command_name" >&2
      missing=1
    fi
  done
  (( missing == 0 ))
}

compose() {
  docker compose \
    --project-directory "$root_dir" \
    --project-name "$COMPOSE_PROJECT_NAME" \
    --env-file "$credentials_file" \
    "$@"
}

wait_until() {
  local timeout_seconds=$1 description=$2
  shift 2
  local deadline=$((SECONDS + timeout_seconds))
  until "$@"; do
    if (( SECONDS >= deadline )); then
      printf 'Timed out after %ss waiting for %s.\n' "$timeout_seconds" "$description" >&2
      return 1
    fi
    sleep 2
  done
}

wait_for_initializers() {
  local timeout_seconds=$1
  shift
  local deadline=$((SECONDS + timeout_seconds))
  local all_complete details exit_code service state

  while true; do
    all_complete=1
    for service in "$@"; do
      details=$(compose ps --all --format json "$service" 2>/dev/null || true)
      state=$(jq -sr '.[0].State // empty' <<<"$details")
      exit_code=$(jq -sr '.[0].ExitCode // empty' <<<"$details")
      if [[ "$state" == exited ]]; then
        if [[ "$exit_code" != 0 ]]; then
          printf 'Initializer %s exited with code %s.\n' "$service" "$exit_code" >&2
          return 1
        fi
      else
        all_complete=0
      fi
    done

    (( all_complete == 1 )) && return 0
    if (( SECONDS >= deadline )); then
      printf 'Timed out after %ss waiting for initializers: %s\n' \
        "$timeout_seconds" "$*" >&2
      return 1
    fi
    sleep 2
  done
}

patroni_port() {
  case "$1" in
    postgres1) printf '%s\n' "${PATRONI1_HOST_PORT:-8008}" ;;
    postgres2) printf '%s\n' "${PATRONI2_HOST_PORT:-8009}" ;;
    postgres3) printf '%s\n' "${PATRONI3_HOST_PORT:-8010}" ;;
    *) return 1 ;;
  esac
}

discover_primary() {
  local service port response primary=''
  for service in postgres1 postgres2 postgres3; do
    port=$(patroni_port "$service")
    response=$(curl --silent --fail "http://127.0.0.1:${port}/primary" 2>/dev/null || true)
    if [[ -n "$response" ]]; then
      if [[ -n "$primary" ]]; then
        printf 'Multiple primaries detected: %s and %s\n' "$primary" "$service" >&2
        return 1
      fi
      primary=$service
    fi
  done
  [[ -n "$primary" ]] || return 1
  printf '%s\n' "$primary"
}

first_running_postgres() {
  local service
  for service in postgres1 postgres2 postgres3; do
    if compose ps --status running --services | grep -qx "$service"; then
      printf '%s\n' "$service"
      return 0
    fi
  done
  return 1
}

sql_via_haproxy() {
  local runner
  runner=$(first_running_postgres)
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" psql -X -v ON_ERROR_STOP=1 \
    -h haproxy -p 5432 -U postgres -d playground "$@"
}

diagnostics() {
  printf '\n=== Compose state ===\n' >&2
  compose ps --all >&2 || true
  printf '\n=== Recent logs ===\n' >&2
  compose logs --tail=80 >&2 || true
  printf '\n=== Patroni APIs ===\n' >&2
  local service port
  for service in postgres1 postgres2 postgres3; do
    port=$(patroni_port "$service")
    printf '%s: ' "$service" >&2
    curl --silent "http://127.0.0.1:${port}/patroni" >&2 || true
    printf '\n' >&2
  done
  printf '\n=== etcd health ===\n' >&2
  compose exec -T etcd1 etcdctl \
    --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
    endpoint health --cluster >&2 || true
  printf '\n=== Kafka topics ===\n' >&2
  compose exec -T kafka timeout 20 /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:29092 --list >&2 || true
  printf '\n=== Connector status ===\n' >&2
  curl --silent "http://127.0.0.1:${CONNECT_HOST_PORT:-8083}/connectors/playground-outbox-connector/status" >&2 || true
  printf '\n' >&2
}
