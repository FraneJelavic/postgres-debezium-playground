#!/usr/bin/env bash
set -Eeuo pipefail

: "${POSTGRES_SUPERUSER_PASSWORD:?POSTGRES_SUPERUSER_PASSWORD is required}"
: "${DEBEZIUM_PASSWORD:?DEBEZIUM_PASSWORD is required}"

export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"

primary_deadline=$((SECONDS + 120))
until psql --host haproxy --port 5432 --username postgres --dbname postgres \
  --tuples-only --no-align \
  --command 'SELECT NOT pg_is_in_recovery()' 2>/dev/null \
  | grep -qx 't'; do
  if (( SECONDS >= primary_deadline )); then
    printf 'Timed out waiting for a writable PostgreSQL primary through HAProxy.\n' >&2
    exit 1
  fi
  sleep 2
done

psql --host haproxy --port 5432 --username postgres --dbname postgres \
  --set=debezium_password="$DEBEZIUM_PASSWORD" \
  --file /init/sql/001-database.sql
psql --host haproxy --port 5432 --username postgres --dbname playground \
  --file /init/sql/002-outbox.sql
psql --host haproxy --port 5432 --username postgres --dbname playground \
  --file /init/sql/003-publication.sql

slot_deadline=$((SECONDS + 120))
until psql --host haproxy --port 5432 --username postgres --dbname playground \
  --tuples-only --no-align \
  --command "SELECT count(*) FROM pg_replication_slots WHERE slot_name = 'playground_slot'" \
  | grep -qx '1'; do
  if (( SECONDS >= slot_deadline )); then
    printf 'Timed out waiting for Patroni to create playground_slot.\n' >&2
    exit 1
  fi
  sleep 2
done

printf 'Database initialization completed.\n'
