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
            where
                event_id = 'EVT-0097'
                and customer_key = {{ erased_member_key() }}
                and is_erased_customer
        ) as erased_fact_count,
        (
            select count(*) from {{ ref('quarantine_customer_events') }}
            where event_id in ('EVT-0097', 'EVT-0099')
        ) as erased_quarantine_count,
        (
            select count(*) from {{ ref('int_customer_events_resolved') }}
            where event_id = 'EVT-0099'
        ) as full_deleted_fact_count
)

select *
from fixture_metrics
where
    late_quarantine_count != 1
    or late_accepted_count != 0
    or erased_fact_count != 1
    or erased_quarantine_count != 0
    or full_deleted_fact_count != 0
