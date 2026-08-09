#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker curl jq openssl

verification_failed() {
  local exit_code=$?
  trap - ERR
  printf 'Verification failed with exit code %s.\n' "$exit_code" >&2
  diagnostics
  exit "$exit_code"
}
trap verification_failed ERR

make_uuid() {
  local value
  value=$(openssl rand -hex 16)
  printf '%s-%s-%s-%s-%s\n' \
    "${value:0:8}" "${value:8:4}" "${value:12:4}" "${value:16:4}" "${value:20:12}"
}

topology_ready() {
  local primary_count=0 replica_count=0 service port
  for service in postgres1 postgres2 postgres3; do
    port=$(patroni_port "$service")
    if curl --fail --silent "http://127.0.0.1:${port}/primary" >/dev/null 2>&1; then
      primary_count=$((primary_count + 1))
    elif curl --fail --silent "http://127.0.0.1:${port}/replica" >/dev/null 2>&1; then
      replica_count=$((replica_count + 1))
    fi
  done
  [[ $primary_count -eq 1 && $replica_count -eq 2 ]]
}

two_streaming_replicas() {
  [[ $(sql_via_haproxy -Atc "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming';" 2>/dev/null) == 2 ]]
}

logical_slot_active() {
  [[ $(sql_via_haproxy -Atc \
    "SELECT count(*) FROM pg_replication_slots WHERE slot_name = 'playground_slot' AND active;" \
    2>/dev/null) == 1 ]]
}

insert_sentinel() {
  local sentinel_id=$1 marker=$2
  [[ "$sentinel_id" =~ ^[0-9a-f-]{36}$ ]]
  [[ "$marker" =~ ^[a-z-]+$ ]]
  sql_via_haproxy \
    --command "INSERT INTO app.verification_sentinels (id, marker) VALUES ('$sentinel_id'::uuid, '$marker');" \
    >/dev/null
}

sentinel_on_service() {
  local service=$1 sentinel_id=$2 count
  [[ "$sentinel_id" =~ ^[0-9a-f-]{36}$ ]]
  count=$(compose exec -T "$service" psql -XAt -U postgres -d playground \
    --command "SELECT count(*) FROM app.verification_sentinels WHERE id = '$sentinel_id'::uuid;" \
    2>/dev/null || true)
  [[ "$count" == 1 ]]
}

sentinel_on_all_members() {
  local sentinel_id=$1 service
  for service in postgres1 postgres2 postgres3; do
    sentinel_on_service "$service" "$sentinel_id" || return 1
  done
}

insert_event() {
  local correlation_id=$1 marker=$2 event_type=$3
  local event_id aggregate_id runner
  event_id=$(make_uuid)
  aggregate_id="order-${correlation_id:0:8}"
  runner=$(first_running_postgres)
  compose exec -T \
    --env "PGPASSWORD=$POSTGRES_SUPERUSER_PASSWORD" \
    "$runner" psql -X -v ON_ERROR_STOP=1 \
    -h haproxy -p 5432 -U postgres -d playground \
    --set=event_id="$event_id" \
    --set=correlation_id="$correlation_id" \
    --set=aggregate_id="$aggregate_id" \
    --set=event_type="$event_type" \
    --set=marker="$marker" \
    --file - < "$root_dir/init/sql/verify-event.sql" >/dev/null
}

consume_topic() {
  # The broker uses the interpreter-only JVM under x86_64 Colima/Rosetta.
  # Allow the one-shot consumer enough time to start and flush its output.
  compose exec -T kafka timeout 60 /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:29092 \
    --topic playground.events.orders \
    --partition 0 \
    --offset earliest \
    --timeout-ms 6000 \
    --property print.key=true \
    --property print.headers=true \
    --property print.value=true 2>/dev/null || true
}

event_seen() {
  local correlation_id=$1 marker=$2 output
  output=$(consume_topic)
  grep -Fq "$correlation_id" <<<"$output" && grep -Fq "$marker" <<<"$output"
}

former_member_streaming() {
  local service=$1 port recovery receiver
  port=$(patroni_port "$service")
  curl --fail --silent "http://127.0.0.1:${port}/replica" >/dev/null 2>&1 || return 1
  recovery=$(compose exec -T "$service" psql -XAt -U postgres -d postgres \
    -c 'SELECT pg_is_in_recovery();' 2>/dev/null || true)
  receiver=$(compose exec -T "$service" psql -XAt -U postgres -d postgres \
    -c "SELECT count(*) FROM pg_stat_wal_receiver WHERE status = 'streaming';" 2>/dev/null || true)
  [[ "$recovery" == t && "$receiver" == 1 ]]
}

printf 'Validating Compose model and building the PostgreSQL/Patroni image...\n'
compose config --quiet
compose build --pull postgres1

printf 'Starting the full stack...\n'
compose up --detach --wait --wait-timeout 240
wait_for_initializers 180 database-init connector-init
wait_until 60 'one primary and two replicas' topology_ready
wait_until 60 'two streaming replicas' two_streaming_replicas

compose exec -T etcd1 etcdctl \
  --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
  endpoint health --cluster >/dev/null
compose exec -T kafka timeout "$kafka_cli_timeout_seconds" /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:29092 --list >/dev/null

wal_level=$(sql_via_haproxy -Atc 'SHOW wal_level;')
[[ "$wal_level" == logical ]]
sql_via_haproxy -Atc "SELECT 1 FROM pg_publication WHERE pubname = 'playground_publication';" | grep -qx 1
wait_until 120 'active playground_slot' logical_slot_active

pre_sentinel=$(make_uuid)
pre_correlation=$(make_uuid)
insert_sentinel "$pre_sentinel" pre-failover
wait_until 60 'pre-failover sentinel replication' sentinel_on_all_members "$pre_sentinel"
insert_event "$pre_correlation" pre-failover ORDER_CREATED
wait_until 180 'pre-failover CDC event' event_seen "$pre_correlation" pre-failover

former_primary=$(discover_primary)
printf 'Stopping discovered primary %s...\n' "$former_primary"
compose stop "$former_primary"

different_primary_ready() {
  local candidate
  candidate=$(discover_primary 2>/dev/null || true)
  [[ -n "$candidate" && "$candidate" != "$former_primary" ]]
}
wait_until 60 'promotion of a different sole primary' different_primary_ready
new_primary=$(discover_primary)

post_sentinel=$(make_uuid)
post_correlation=$(make_uuid)
insert_sentinel "$post_sentinel" post-failover
insert_event "$post_correlation" post-failover ORDER_UPDATED
wait_until 180 'post-failover CDC event' event_seen "$post_correlation" post-failover

compose start "$former_primary"
wait_until 120 "$former_primary to rejoin as a streaming replica" former_member_streaming "$former_primary"
wait_until 60 'post-failover sentinel on the former primary' sentinel_on_service "$former_primary" "$post_sentinel"
wait_until 60 'restored three-member topology' topology_ready

all_events=$(consume_topic)
pre_count=$(grep -Fc "$pre_correlation" <<<"$all_events" || true)
post_count=$(grep -Fc "$post_correlation" <<<"$all_events" || true)
(( pre_count >= 1 && post_count >= 1 ))
printf 'CDC observations: pre-failover=%s, post-failover=%s (duplicates are allowed).\n' \
  "$pre_count" "$post_count"

printf 'Restarting long-running services without deleting volumes...\n'
compose restart etcd1 etcd2 etcd3 postgres1 postgres2 postgres3 haproxy kafka connect
compose up --detach --wait --wait-timeout 240
wait_until 90 'topology after non-destructive restart' topology_ready
wait_until 90 'streaming replication after non-destructive restart' two_streaming_replicas

sql_via_haproxy -Atc "SELECT count(*) FROM app.verification_sentinels WHERE id IN ('$pre_sentinel', '$post_sentinel');" | grep -qx 2
wait_until 180 'persisted pre-failover CDC event' event_seen "$pre_correlation" pre-failover
wait_until 180 'persisted post-failover CDC event' event_seen "$post_correlation" post-failover
curl --fail --silent \
  "http://127.0.0.1:${CONNECT_HOST_PORT}/connectors/playground-outbox-connector/config" \
  | jq -e '."slot.name" == "playground_slot" and ."publication.name" == "playground_publication"' >/dev/null

trap - ERR
printf 'Verification passed: %s promoted to %s; CDC, rejoin, and persistence assertions succeeded.\n' \
  "$former_primary" "$new_primary"
