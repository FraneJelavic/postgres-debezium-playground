# Compatibility Matrix

Validated selections as of 2026-08-08:

| Component | Readable version | Immutable multi-platform digest | amd64 | arm64 |
|---|---|---|:---:|:---:|
| PostgreSQL base/client | `postgres:16.14-bookworm` | `sha256:64154d0babcb1741988719e703419af0382b19953706149f9872fbd0f438efa8` | yes | yes |
| Patroni | `4.1.4` | PyPI distributions pinned by SHA-256 in `requirements.txt` | yes | yes |
| etcd | `quay.io/coreos/etcd:v3.5.33` | `sha256:d367cba7801b29d2f7481bb56802894658ec8a647834509118c81f77f721381b` | yes | yes |
| HAProxy | `haproxy:3.2.22-alpine` | `sha256:79799e8b2977e60802774fa53d29e6b54e045402cdd8a8b9fe43923e7095a047` | yes | yes |
| Apache Kafka | `apache/kafka:4.3.1` | `sha256:77e3df9054047a88b520d0cc46e16696d3b22022e1d580aeccd2632df6532837` | yes | yes |
| Debezium Connect | `quay.io/debezium/connect:3.6.1` | `sha256:624de53c4da93aa2f845483449c7c26d0ed1f816eac06f2f476f79b3ab50abb5` | yes | yes |

Manifest inspection confirmed both `linux/amd64` and `linux/arm64`. Release configuration uses the listed digests; readable tags remain beside them for maintenance.

## Host prerequisites

- Docker Engine 27 or newer.
- Docker Compose plugin 2.30 or newer (`docker compose`, not legacy `docker-compose`).
- Colima 0.8 or newer on macOS.
- `bash`, `curl`, `jq`, `openssl`, and `make` on the host.
- Starting Colima allocation: 4 CPUs, 8 GiB RAM, and 30 GiB disk.

The full runtime scenario is required on both architectures before both are claimed in a release. Image availability alone is not runtime certification.
