# CDC Flow

1. A transaction writes an `app.outbox_events` row through HAProxy.
2. PostgreSQL includes the row in `playground_publication` and exposes it through Patroni's permanent `playground_slot` using `pgoutput`.
3. Debezium Connect reconnects through HAProxy after primary changes.
4. The built-in Outbox Event Router emits `playground.events.<aggregate_type>`.
5. Kafka stores the record in the single KRaft broker.

The record key is `aggregate_id`. The value is `payload`. Verification searches the value for a unique caller-supplied correlation ID.

The heartbeat action updates `app.debezium_heartbeat` every ten seconds during idle periods, allowing the connector to advance the logical slot and limiting avoidable WAL retention.

To observe the failure mode without a source heartbeat—and the recovery after restoring `heartbeat.action.query`—run [the WAL heartbeat demo](wal-heartbeat-demo.md) (`make demo-wal-heartbeat`). That demo loads a separate `noise` database with pgbench so captured tables stay quiet.

Failover delivery is at-least-once. Duplicates are valid; missing expected correlation IDs are not.
