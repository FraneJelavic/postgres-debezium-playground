\set ON_ERROR_STOP on
\connect playground

CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.outbox_events (
    id uuid PRIMARY KEY,
    correlation_id uuid NOT NULL,
    aggregate_type varchar(100) NOT NULL,
    aggregate_id varchar(200) NOT NULL,
    event_type varchar(100) NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT outbox_events_correlation_id_key UNIQUE (correlation_id)
);

CREATE TABLE IF NOT EXISTS app.debezium_heartbeat (
    id integer PRIMARY KEY,
    updated_at timestamptz NOT NULL,
    connector_name varchar(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS app.verification_sentinels (
    id uuid PRIMARY KEY,
    marker text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO app.debezium_heartbeat (id, updated_at, connector_name)
VALUES (1, clock_timestamp(), 'playground-outbox-connector')
ON CONFLICT (id) DO UPDATE
SET updated_at = EXCLUDED.updated_at,
    connector_name = EXCLUDED.connector_name;

GRANT CONNECT ON DATABASE playground TO debezium;
GRANT USAGE ON SCHEMA app TO debezium;
GRANT SELECT ON app.outbox_events, app.debezium_heartbeat TO debezium;
GRANT INSERT, UPDATE ON app.debezium_heartbeat TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO debezium;
