#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker curl jq

printf '=== Compose services ===\n'
compose ps --all

printf '\n=== etcd cluster ===\n'
compose exec -T etcd1 etcdctl \
  --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
  endpoint health --cluster

printf '\n=== Patroni members ===\n'
for service in postgres1 postgres2 postgres3; do
  port=$(patroni_port "$service")
  curl --fail --silent "http://127.0.0.1:${port}/patroni" \
    | jq --arg service "$service" '{service: $service, state, role, server_version, xlog}'
done
primary=$(discover_primary)
printf 'Current primary: %s\n' "$primary"

printf '\n=== HAProxy write endpoint ===\n'
sql_via_haproxy --tuples-only --no-align --command 'SELECT current_database(), pg_is_in_recovery();'

printf '\n=== Kafka topics ===\n'
compose exec -T kafka timeout 30 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:29092 --list

printf '\n=== Connector ===\n'
curl --fail --silent \
  "http://127.0.0.1:${CONNECT_HOST_PORT}/connectors/playground-outbox-connector/status" | jq .

printf '\n=== Publication and logical slot ===\n'
sql_via_haproxy --command "SELECT pubname FROM pg_publication WHERE pubname = 'playground_publication';"
sql_via_haproxy --command "SELECT slot_name, slot_type, plugin, active FROM pg_replication_slots WHERE slot_name = 'playground_slot';"
