# Getting Started

## Prerequisites

Use the versions in `docs/compatibility.md`. Colima should have at least 4 CPUs, 8 GiB memory, and 30 GiB disk:

```sh
colima start --cpu 4 --memory 8 --disk 30
docker version
docker compose version
```

## Start and inspect

```sh
make init
make up
make status
```

Initialization is idempotent. Re-running it preserves `.state/credentials.env`; resetting the lab is the explicit way to rotate local credentials.

Connect a PostgreSQL client to `127.0.0.1:5432`, database `playground`, user `postgres`, using the generated password. New connections always target the current Patroni primary.

To insert a sample event, use a new UUID for both `id` and `correlation_id`:

```sql
INSERT INTO app.outbox_events
  (id, correlation_id, aggregate_type, aggregate_id, event_type, payload)
VALUES
  ('11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222',
   'orders', 'order-42', 'ORDER_CREATED', '{"order_id":"order-42"}');
```

Consume `playground.events.orders` from `127.0.0.1:9092`. The Kafka key is the aggregate ID; the value is the JSON payload.

## Stop and reset

`make down` preserves PostgreSQL, etcd, and Kafka volumes. `make reset` prints the exact project and volumes, requires confirmation, and deletes generated credentials. Reset is irreversible unless the Docker volumes were backed up separately.
