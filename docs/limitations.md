# Limitations

- All redundancy is inside one Docker/Colima host; host loss stops every component.
- PostgreSQL replication is asynchronous, so acknowledged transactions can be absent from a promoted replica.
- PostgreSQL 16 and Patroni logical-slot synchronization are observed as a lab behavior, not a zero-loss guarantee.
- CDC is at-least-once; failover may produce duplicates.
- Kafka, Connect, and HAProxy are single instances.
- Existing client connections can break during primary promotion and must reconnect.
- There are no backups, PITR, TLS, multi-host scheduling, monitoring, or production security controls.
- Normal shutdown preserves volumes. `make reset` is deliberately destructive and must be explicit.
