# Failover Scenario

Run `make failover` to perform a bounded failover:

1. Query all Patroni APIs and identify the sole `/primary` member.
2. Stop that Compose service.
3. Require a different sole primary within 60 seconds.
4. Restart the former primary.
5. Require it to report as a replica with an active streaming WAL receiver.

The application address remains `127.0.0.1:5432`, but open database connections can fail and must reconnect. Because replication is asynchronous, the exercise does not guarantee that every acknowledged transaction is present after promotion.

`make verify` extends this scenario with correlated CDC events before and after promotion, a catch-up assertion, and a persistence restart.
