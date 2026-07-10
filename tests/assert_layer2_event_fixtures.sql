{{ config(tags=['layer2_events', 'control_fixture', 'deletion_control']) }}

with fixture_metrics as (
    select
        (
            select count(*)
            from {{ ref('quarantine_customer_events') }}
            where event_id = 'EVT-0098' and quarantine_reason = 'CUSTOMER_NOT_FOUND'
        ) as late_quarantine_count,
        (
            select count(*)
            from {{ ref('int_customer_events_resolved') }}
            where event_id = 'EVT-0098'
        ) as late_accepted_count,
        (
            select count(*)
            from {{ ref('int_customer_events_resolved') }}
            where event_id = 'EVT-0099'
        ) + (
            select count(*)
            from {{ ref('quarantine_customer_events') }}
            where event_id = 'EVT-0099'
        ) as deleted_output_count
)

select *
from fixture_metrics
where
    late_quarantine_count != 1
    or late_accepted_count != 0
    or deleted_output_count != 0
