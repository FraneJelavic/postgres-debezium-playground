# Troubleshooting

Start with `make status` and `docker compose --env-file .state/credentials.env ps`.

## Colima resources

Repeated OOM kills, slow Kafka startup, or promotion timeouts usually mean the VM has fewer than 4 CPUs or 8 GiB memory. Stop Colima, increase its allocation, and start it again.

## Architecture or image pulls

Confirm the host reports `amd64` or `arm64` and compare image digests with `docs/compatibility.md`. A stale mutable tag is not part of the supported configuration.

## Unhealthy PostgreSQL or etcd

Inspect `docker compose logs etcd1 etcd2 etcd3 postgres1 postgres2 postgres3`. Stale volumes from incompatible versions require the explicit `make reset` path; do not delete arbitrary Docker data.

## HAProxy

HAProxy becomes healthy only when a Patroni member answers `/primary`. Check `curl http://127.0.0.1:8008/patroni` through port 8010 and verify there is exactly one primary.

## Connector or slot

Inspect `curl http://127.0.0.1:8083/connectors/playground-outbox-connector/status`. Confirm the publication and slot with `make status`. A failed connector task is a hard failure, not a warning.

## Kafka listeners

Containers use `kafka:29092`; host clients use `127.0.0.1:9092`. Using the host listener from a container, or the internal listener from the host, causes metadata connection failures.
