# WAL Heartbeat Demo

This scenario reproduces the quiet-table WAL retention problem: Debezium can be `RUNNING` while a PostgreSQL logical slot retains WAL, because the connector has no published change to acknowledge. A source heartbeat (`heartbeat.action.query`) closes that gap.

Do not validate the fix with writes to a captured table. That traffic already moves the slot and hides the failure. The demo generates sustained writes only in a separate `noise` database that is outside `playground_publication`.

## Prerequisites

```sh
make init
make up
make status
```

## Run

```sh
make demo-wal-heartbeat
```

Optional knobs:

| Variable | Default | Purpose |
|---|---|---|
| `WAL_DEMO_LOAD_SECONDS` | `45` | pgbench duration per phase |
| `WAL_DEMO_MIN_GROWTH_BYTES` | `5242880` | minimum retained-WAL growth required in phase 1 |

## What the demo does

1. Saves the current connector configuration.
2. Removes only `heartbeat.action.query`, leaving `heartbeat.interval.ms` in place so a connector-side heartbeat alone can be shown as insufficient.
3. Initializes pgbench tables in database `noise` and runs a timed load. Captured tables stay quiet.
4. Asserts that `confirmed_flush_lsn` stalls while retained WAL for `playground_slot` grows.
5. Restores `heartbeat.action.query` against `app.debezium_heartbeat`.
6. Repeats the same off-publication load and asserts that the heartbeat row updates, `confirmed_flush_lsn` advances, and retained WAL growth stays well below the stalled-slot phase.
7. Restores the original connector configuration.

## Slot metrics to watch

```sql
SELECT
    slot_name,
    active,
    wal_status,
    restart_lsn,
    confirmed_flush_lsn,
    pg_current_wal_lsn() AS current_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots
WHERE slot_name = 'playground_slot';
```

Watch the numeric retained bytes and whether `confirmed_flush_lsn` moves. Connector state alone does not answer whether PostgreSQL can recycle WAL.
