#!/usr/bin/env bash
set -Eeuo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="$root_dir/.state"
credentials_file="$state_dir/credentials.env"

if [[ -f "$credentials_file" ]]; then
  printf 'Reusing existing credentials at %s\n' "$credentials_file"
  exit 0
fi

command -v openssl >/dev/null 2>&1 || {
  printf 'openssl is required.\n' >&2
  exit 1
}

umask 077
mkdir -p "$state_dir"

tmp_file="$state_dir/credentials.env.tmp"
{
  printf 'COMPOSE_PROJECT_NAME=postgres-debezium-playground\n'
  printf 'POSTGRES_HOST_PORT=5432\n'
  printf 'KAFKA_HOST_PORT=9092\n'
  printf 'CONNECT_HOST_PORT=8083\n'
  printf 'PATRONI1_HOST_PORT=8008\n'
  printf 'PATRONI2_HOST_PORT=8009\n'
  printf 'PATRONI3_HOST_PORT=8010\n'
  printf 'POSTGRES_SUPERUSER_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  printf 'POSTGRES_REPLICATION_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  printf 'POSTGRES_REWIND_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  printf 'DEBEZIUM_PASSWORD=%s\n' "$(openssl rand -hex 24)"
} > "$tmp_file"
chmod 0600 "$tmp_file"
mv "$tmp_file" "$credentials_file"

printf 'Generated local credentials at %s (mode 0600).\n' "$credentials_file"
