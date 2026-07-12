{{ config(tags=['layer2_events', 'deletion_control']) }}

with
expected_events as (
    select events.event_id
    from {{ ref('int_customer_events_keyed') }} as events
),

actual_event_counts as (
    select event_id, count(*) as occurrence_count
    from (
        select event_id from {{ ref('int_customer_events_resolved') }}
        union all
        select event_id from {{ ref('quarantine_customer_events') }}
    ) as outputs
    group by event_id
),

partition_differences as (
    select
        coalesce(expected.event_id, actual.event_id) as event_id,
        expected.event_id is not null as expected_to_exist,
        coalesce(actual.occurrence_count, 0) as occurrence_count
    from expected_events as expected
    full outer join actual_event_counts as actual
        on expected.event_id = actual.event_id
    where expected.event_id is null or coalesce(actual.occurrence_count, 0) != 1
)

select *
from partition_differences
