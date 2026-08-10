# Compatibility Matrix

Validated selections as of 2026-08-10:

| Component | Version | amd64 | arm64 |
|---|---|:---:|:---:|
| PostgreSQL base/client | `postgres:16.14-bookworm` | yes | yes |
| Patroni | `4.1.4` | yes | yes |
| etcd | `quay.io/coreos/etcd:v3.5.33` | yes | yes |
| HAProxy | `haproxy:3.2.22-alpine` | yes | yes |
| Apache Kafka | `apache/kafka:4.3.1` | yes | yes |
| Debezium Connect | `quay.io/debezium/connect:3.6.1` | yes | yes |

Manifest inspection confirmed both `linux/amd64` and `linux/arm64`. Runtime and build inputs use explicit version tags so dependency automation can maintain them. Upstream publishers can repoint tags; review dependency updates and CI results before release.

## Host prerequisites

- Docker Engine 27 or newer.
- Docker Compose plugin 2.30 or newer (`docker compose`, not legacy `docker-compose`).
- Colima 0.8 or newer on macOS.
- `bash`, `curl`, `jq`, `openssl`, and `make` on the host.
- Starting Colima allocation: 4 CPUs, 8 GiB RAM, and 30 GiB disk.

The full runtime scenario is required on both architectures before both are claimed in a release. Image availability alone is not runtime certification.
