# Provenance

This repository is an independently authored, clean-history implementation based only on public upstream documentation. Internal commits, branches, tags, images, binaries, credentials, schemas, topics, names, generated assets, and Git objects must never be imported.

## Public sources

| Component | Source used | License | Selection and integrity policy |
|---|---|---|---|
| PostgreSQL | https://www.postgresql.org/docs/16/ and Docker Official Image | PostgreSQL License | PostgreSQL 16 Bookworm patch releases selected by explicit version tag. |
| Patroni | https://patroni.readthedocs.io/ and https://github.com/patroni/patroni | MIT | Exact PyPI version with all transitive Python distributions pinned and hashed. |
| etcd | https://etcd.io/docs/ and `quay.io/coreos/etcd` | Apache-2.0 | Selected 3.5 patch release identified by explicit version tag. |
| HAProxy | https://docs.haproxy.org/ | GPL-2.0-or-later with linking exception | Stable branch patch release identified by explicit version tag. |
| Apache Kafka | https://kafka.apache.org/documentation/ and `apache/kafka` | Apache-2.0 | Stable KRaft release identified by explicit version tag. |
| Debezium | https://debezium.io/documentation/reference/3.6/ | Apache-2.0 | Stable Connect release identified by explicit version tag. |
| Docker Compose | https://docs.docker.com/compose/ | Apache-2.0 | Compose v2 plugin; minimum version documented in the compatibility matrix. |
| C4/Structurizr | https://docs.structurizr.com/dsl | Apache-2.0 | Editable DSL is repository-authored; rendering tools use explicit version tags. |

No file in this repository was copied from the private behavioral reference. The public design uses generic identifiers and upstream configuration contracts.

## Release gates

Before the first public commit or any visibility change, the repository owner must record outside this repository:

1. Written ownership and open-source authorization.
2. Approved Apache-2.0 copyright and NOTICE wording.
3. Completion or formal tracking of historical credential and image-layer remediation.
4. Source-similarity, secret, license, trademark, and asset-provenance approval for the exact release tree.

These are organizational release blockers; local development does not imply approval.
