\set ON_ERROR_STOP on
\connect playground

SELECT 'CREATE PUBLICATION playground_publication FOR TABLE app.outbox_events, app.debezium_heartbeat'
WHERE NOT EXISTS (
    SELECT FROM pg_publication WHERE pubname = 'playground_publication'
)
\gexec

ALTER PUBLICATION playground_publication
    SET TABLE app.outbox_events, app.debezium_heartbeat;
