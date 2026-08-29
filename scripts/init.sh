#!/usr/bin/env bash
set -Eeuo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="$root_dir/.state"
credentials_file="$state_dir/credentials.env"
# Development-only shared password for every local role.
local_password='test'

if [[ -f "$credentials_file" ]]; then
  printf 'Reusing existing credentials at %s\n' "$credentials_file"
  exit 0
fi

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
  # Development-only credentials. Every local role shares one obvious password.
  printf 'POSTGRES_SUPERUSER_PASSWORD=%s\n' "$local_password"
  printf 'POSTGRES_REPLICATION_PASSWORD=%s\n' "$local_password"
  printf 'POSTGRES_REWIND_PASSWORD=%s\n' "$local_password"
  printf 'DEBEZIUM_PASSWORD=%s\n' "$local_password"
} > "$tmp_file"
chmod 0600 "$tmp_file"
mv "$tmp_file" "$credentials_file"

printf 'Wrote local development credentials to %s (mode 0600).\n' "$credentials_file"
