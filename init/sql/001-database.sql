\set ON_ERROR_STOP on

SELECT format('CREATE ROLE debezium WITH LOGIN REPLICATION PASSWORD %L', :'debezium_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'debezium')
\gexec

SELECT format('ALTER ROLE debezium WITH LOGIN REPLICATION PASSWORD %L', :'debezium_password')
\gexec

SELECT 'CREATE DATABASE playground'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'playground')
\gexec
