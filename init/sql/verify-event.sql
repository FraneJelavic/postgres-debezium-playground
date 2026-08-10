\set ON_ERROR_STOP on

INSERT INTO app.outbox_events (id,
                               correlation_id,
                               aggregate_type,
                               aggregate_id,
                               event_type,
                               payload)
VALUES (:'event_id'::uuid,
        :'correlation_id'::uuid,
        'orders',
        :'aggregate_id',
        :'event_type',
        jsonb_build_object(
                'correlation_id', :'correlation_id',
                'marker', :'marker',
                'aggregate_id', :'aggregate_id'
        ));
