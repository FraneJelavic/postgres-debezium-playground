# Security Model

This lab uses plaintext traffic on a private Compose bridge. Host mappings bind only to `127.0.0.1`; etcd and PostgreSQL member ports are not published. Exposed loopback endpoints are HAProxy PostgreSQL, Kafka, Connect REST, and three read-only Patroni diagnostic APIs.

`make init` creates random local passwords in `.state/credentials.env`, sets mode `0600`, and reuses the file unless the user explicitly resets it. The file is ignored by Git and excluded from Docker build contexts. Secrets are passed through the Compose environment and are not rendered into tracked connector JSON.

The lab has no TLS, network authentication, external secret manager, audit pipeline, hardening baseline, or public ingress. Any process on the host may be able to reach loopback ports. Do not use real, shared, or production data.
