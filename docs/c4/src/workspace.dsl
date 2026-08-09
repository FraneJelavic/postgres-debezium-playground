workspace "PostgreSQL Debezium Playground" "Single-host lab for observing PostgreSQL leader failover and Debezium CDC." {
    !identifiers hierarchical

    model {
        developer = person "Developer" "Starts the lab, writes outbox events, triggers failover, and observes PostgreSQL and Kafka state."
        dockerHost = softwareSystem "Docker Engine or Colima" "Runs every playground process and named volume on one host."
        registries = softwareSystem "Public upstream registries" "Supply the pinned PostgreSQL, etcd, HAProxy, Kafka, and Debezium images."

        playground = softwareSystem "PostgreSQL Debezium Playground" "Educational, single-host PostgreSQL HA and CDC environment." {
            group "Three-member DCS quorum" {
                etcd1 = container "etcd 1" {
                    description "Voting DCS member."
                    technology "etcd 3.5"
                    tags "Redundant"
                }
                etcd2 = container "etcd 2" {
                    description "Voting DCS member."
                    technology "etcd 3.5"
                    tags "Redundant"
                }
                etcd3 = container "etcd 3" {
                    description "Voting DCS member."
                    technology "etcd 3.5"
                    tags "Redundant"
                }
            }

            group "PostgreSQL high availability" {
                haproxy = container "HAProxy" {
                    description "Stable write endpoint; routes new connections only to the current Patroni primary."
                    technology "HAProxy 3.2"
                    tags "SingleInstance"
                }
                postgres1 = container "PostgreSQL + Patroni 1" {
                    description "Primary or asynchronous streaming replica; roles are dynamic."
                    technology "PostgreSQL 16 / Patroni 4"
                    tags "Redundant,Database"
                }
                postgres2 = container "PostgreSQL + Patroni 2" {
                    description "Primary or asynchronous streaming replica; roles are dynamic."
                    technology "PostgreSQL 16 / Patroni 4"
                    tags "Redundant,Database"
                }
                postgres3 = container "PostgreSQL + Patroni 3" {
                    description "Primary or asynchronous streaming replica; roles are dynamic."
                    technology "PostgreSQL 16 / Patroni 4"
                    tags "Redundant,Database"
                }
            }

            group "Single-instance CDC pipeline" {
                connect = container "Debezium Connect" {
                    description "Reads the logical slot and applies the standard Outbox Event Router."
                    technology "Debezium Connect 3.6"
                    tags "SingleInstance"
                }
                kafka = container "Kafka broker/controller" {
                    description "Stores outbox events and Connect internal state in one KRaft node."
                    technology "Apache Kafka 4.3 / KRaft"
                    tags "SingleInstance"
                }
            }

            group "One-shot initialization" {
                databaseInit = container "Database initializer" {
                    description "Creates roles, schema, tables, publication, and grants idempotently."
                    technology "Bash / psql"
                    tags "Initializer"
                }
                connectorInit = container "Connector initializer" {
                    description "Creates or updates the connector and requires its task to run."
                    technology "Bash / Connect REST"
                    tags "Initializer"
                }
            }

            group "Project-scoped named volumes" {
                etcd1Volume = container "etcd1-data" {
                    description "Persistent etcd member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                etcd2Volume = container "etcd2-data" {
                    description "Persistent etcd member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                etcd3Volume = container "etcd3-data" {
                    description "Persistent etcd member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                postgres1Volume = container "postgres1-data" {
                    description "Persistent PostgreSQL member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                postgres2Volume = container "postgres2-data" {
                    description "Persistent PostgreSQL member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                postgres3Volume = container "postgres3-data" {
                    description "Persistent PostgreSQL member data."
                    technology "Docker volume"
                    tags "Volume"
                }
                kafkaVolume = container "kafka-data" {
                    description "Persistent Kafka log and metadata data."
                    technology "Docker volume"
                    tags "Volume"
                }
            }

            haproxy -> postgres1 "Routes writes when primary" "PostgreSQL" "Data"
            haproxy -> postgres2 "Routes writes when primary" "PostgreSQL" "Data"
            haproxy -> postgres3 "Routes writes when primary" "PostgreSQL" "Data"

            postgres1 -> etcd1 "Reads/writes cluster state" "HTTP" "Control"
            postgres1 -> etcd2 "Reads/writes cluster state" "HTTP" "Control"
            postgres1 -> etcd3 "Reads/writes cluster state" "HTTP" "Control"
            postgres2 -> etcd1 "Reads/writes cluster state" "HTTP" "Control"
            postgres2 -> etcd2 "Reads/writes cluster state" "HTTP" "Control"
            postgres2 -> etcd3 "Reads/writes cluster state" "HTTP" "Control"
            postgres3 -> etcd1 "Reads/writes cluster state" "HTTP" "Control"
            postgres3 -> etcd2 "Reads/writes cluster state" "HTTP" "Control"
            postgres3 -> etcd3 "Reads/writes cluster state" "HTTP" "Control"

            postgres1 -> postgres2 "Streams WAL while primary" "PostgreSQL replication" "Replication"
            postgres2 -> postgres3 "Streams WAL while primary" "PostgreSQL replication" "Replication"
            postgres3 -> postgres1 "Streams WAL while primary" "PostgreSQL replication" "Replication"

            connect -> haproxy "Reads playground_publication via playground_slot" "pgoutput" "CDC"
            connect -> kafka "Publishes routed outbox events and Connect state" "Kafka protocol" "CDC"
            databaseInit -> haproxy "Creates database objects through the stable endpoint" "PostgreSQL" "Control"
            connectorInit -> connect "Creates or updates the connector" "HTTP/JSON" "Control"

            etcd1 -> etcd1Volume "Persists state" "Filesystem" "Persistence"
            etcd2 -> etcd2Volume "Persists state" "Filesystem" "Persistence"
            etcd3 -> etcd3Volume "Persists state" "Filesystem" "Persistence"
            postgres1 -> postgres1Volume "Persists data and WAL" "Filesystem" "Persistence"
            postgres2 -> postgres2Volume "Persists data and WAL" "Filesystem" "Persistence"
            postgres3 -> postgres3Volume "Persists data and WAL" "Filesystem" "Persistence"
            kafka -> kafkaVolume "Persists logs and metadata" "Filesystem" "Persistence"
        }

        developer -> playground "Uses make targets and localhost-only endpoints"
        playground -> dockerHost "Runs entirely on" "Docker Compose"
        registries -> dockerHost "Provide pinned public images" "HTTPS"

        developer -> playground.haproxy "Writes SQL and outbox events" "PostgreSQL"
        developer -> playground.kafka "Observes routed events" "Kafka protocol"
        developer -> playground.connect "Inspects connector state" "HTTP/JSON"
    }

    views {
        systemContext playground "context" {
            include *
            include registries
            autolayout lr
            title "PostgreSQL Debezium Playground - System Context"
            description "A developer runs and observes an educational CDC/failover lab on one Docker or Colima host."
        }

        container playground "containers" {
            include *
            autolayout tb
            title "PostgreSQL Debezium Playground - Containers"
            description "Green elements are redundant processes; orange elements remain single-instance. All processes share one host."
        }

        styles {
            element "Element" {
                color #ffffff
                fontSize 20
            }
            element "Person" {
                shape person
                background #08427b
            }
            element "Software System" {
                background #1168bd
            }
            element "Container" {
                background #438dd5
            }
            element "Redundant" {
                background #2e7d32
            }
            element "SingleInstance" {
                background #ef6c00
            }
            element "Initializer" {
                background #546e7a
            }
            element "Volume" {
                shape cylinder
                background #5d4037
            }
            element "Database" {
                shape cylinder
            }
            element "Group" {
                color #263238
                stroke #607d8b
            }
            relationship "Relationship" {
                color #455a64
                fontSize 16
            }
            relationship "Control" {
                dashed true
                color #616161
            }
            relationship "CDC" {
                color #6a1b9a
                thickness 4
            }
            relationship "Replication" {
                color #2e7d32
                dashed true
            }
            relationship "Persistence" {
                color #5d4037
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}
