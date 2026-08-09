# Third-Party Notices

The playground downloads and runs unmodified upstream software. Each project remains governed by its own license.

| Dependency | Version | Registry/source | License |
|---|---:|---|---|
| PostgreSQL image | 16.14-bookworm | docker.io/library/postgres | PostgreSQL License |
| Patroni | 4.1.4 | pypi.org/project/patroni | MIT |
| etcd | 3.5.33 | quay.io/coreos/etcd | Apache-2.0 |
| HAProxy | 3.2.22-alpine | docker.io/library/haproxy | GPL-2.0-or-later with linking exception |
| Apache Kafka | 4.3.1 | docker.io/apache/kafka | Apache-2.0 |
| Debezium Connect | 3.6.1 | quay.io/debezium/connect | Apache-2.0 |
| Structurizr CLI (rendering only) | 2025.11.09 | docker.io/structurizr/cli | Apache-2.0 |
| PlantUML (rendering only) | 1.2026.6 | docker.io/plantuml/plantuml | GPL-3.0-or-later |

The complete Python dependency lock, including package hashes, is in `images/postgres-patroni/requirements.txt`. Container image digests and supported architectures are in `docs/compatibility.md`.
