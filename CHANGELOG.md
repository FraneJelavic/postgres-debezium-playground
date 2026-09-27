# Changelog

All notable changes follow Keep a Changelog and Semantic Versioning.

## Unreleased

### Added

- Clean-room PostgreSQL 16, Patroni, etcd, HAProxy, Kafka KRaft, and Debezium playground.
- Integrated failover, CDC, rejoin, and persistence verification.
- `make demo-wal-heartbeat` scenario that stalls the logical slot under off-publication pgbench traffic, then advances it again with `heartbeat.action.query`.
- Public dependency, security, provenance, CI, and release documentation.

### Fixed

- Apply Debian security upgrades during the Patroni image build so Trivy no longer flags fixed `libpcre2` CVEs.
