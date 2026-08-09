# Verification Contract

`make verify` is the executable acceptance contract.

- Compose readiness deadline: 240 seconds.
- PostgreSQL promotion deadline: 60 seconds.
- Exactly one primary and two streaming replicas before failover.
- All three etcd endpoints healthy.
- Writes through the stable HAProxy address visible on both replicas.
- One uniquely correlated CDC event before promotion and one after promotion.
- A different sole primary after stopping the discovered leader.
- The former primary rejoins as a caught-up streaming replica.
- Database rows, Kafka data, and connector configuration survive a non-destructive restart.

CDC acceptance is at-least-once: every expected correlation ID must be observed. Duplicate records are counted and reported but do not fail verification; missing records fail it. This does not assert exactly-once delivery or zero data loss under arbitrary host failure.

On failure, verification prints Compose state, recent logs, Patroni state, etcd health, Kafka metadata, connector state, publication state, and logical-slot state. It never removes volumes.
