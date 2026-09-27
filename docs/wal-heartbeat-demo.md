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

To record a three-pane desktop video (operations / slot WAL / heartbeat row) on an X11 session:

```sh
make up
make record-wal-heartbeat
```

`make record-wal-heartbeat` opens a maximized terminal with tmux panes, drives the config and pgbench steps in pane 1, watches `playground_slot` retained WAL in pane 2, and watches `app.debezium_heartbeat` in pane 3 while capturing the display to `wal_heartbeat_three_pane_demo.mp4` under `ARTIFACT_DIR` (default `/opt/cursor/artifacts`).

Optional knobs:

| Variable | Default | Purpose |
|---|---|---|
| `WAL_DEMO_LOAD_SECONDS` | `45` (`20` for `record-wal-heartbeat`) | pgbench duration per phase |
| `WAL_DEMO_MIN_GROWTH_BYTES` | `5242880` | minimum retained-WAL growth required in phase 1 |
| `ARTIFACT_DIR` | `/opt/cursor/artifacts` | output directory for `record-wal-heartbeat` |
| `VIDEO_PATH` | `$ARTIFACT_DIR/wal_heartbeat_three_pane_demo.mp4` | recording path |
| `DISPLAY` | `:1` | X display captured by ffmpeg |

## What the demo does

1. Saves the current connector configuration.
2. Removes only `heartbeat.action.query`, leaving `heartbeat.interval.ms` in place so a connector-side heartbeat alone can be shown as insufficient.
3. Initializes pgbench tables in database `noise` and runs a timed load. Captured tables stay quiet.
4. Asserts that `confirmed_flush_lsn` stalls while retained WAL for `playground_slot` grows.
5. Restores `heartbeat.action.query` against `app.debezium_heartbeat`.
6. Repeats the same off-publication load and asserts that the heartbeat row updates and `confirmed_flush_lsn` advances.
7. Waits after the load for `restart_lsn` to catch up so retained WAL is reclaimed — proving the slot is no longer pinning WAL without bound.
8. Restores the original connector configuration.

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
