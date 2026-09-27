# Media for the Debezium WAL heartbeat article

Clips split from the three-pane playground demo for
`When Debezium Does Not Advance a PostgreSQL Replication Slot`.

| File | Duration | Use in article |
|---|---|---|
| `01-without-source-heartbeat.mp4` | ~47s | After removing `heartbeat.action.query`: off-publication `pgbench`, stalled `confirmed_flush_lsn`, growing retained WAL, frozen heartbeat `age` |
| `02-with-source-heartbeat.mp4` | ~95s | After restoring `heartbeat.action.query`: heartbeat row moves again, slot advances, retained WAL reclaims |
| `01-without-source-heartbeat.png` | still | Optional poster / inline still for part 1 |
| `02-with-source-heartbeat.png` | still | Optional poster / inline still for part 2 |
| `full-three-pane-recording.mp4` | ~142s | Full uncut recording (reference only; not needed in the post) |

Suggested place in Hugo: keep these next to `index.md` (page bundle) or under `static/…` and link accordingly.

See `index-media-snippet.md` for copy-paste markup aimed at the **Prove that the heartbeat works** section.
