#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker curl jq

if ! compose config --quiet; then
  exit 1
fi

if ! compose up --detach --build --wait --wait-timeout 240; then
  diagnostics
  exit 1
fi

if ! wait_for_initializers 180 database-init connector-init; then
  diagnostics
  exit 1
fi

printf 'Playground is healthy. PostgreSQL: 127.0.0.1:%s, Kafka: 127.0.0.1:%s, Connect: 127.0.0.1:%s\n' \
  "$POSTGRES_HOST_PORT" "$KAFKA_HOST_PORT" "$CONNECT_HOST_PORT"
