{{ config(tags=['layer2_events', 'deletion_control']) }}

with expected_events as (
    select
        events.event_id,
        case
            when ledger.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION' then 0
            else 1
        end as expected_occurrence_count
    from {{ ref('int_customer_events_keyed') }} as events
    left join {{ ref('int_terminal_deleted_customer_keys') }} as ledger
        on events.customer_key = ledger.customer_key
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
        expected.expected_occurrence_count,
        coalesce(actual.occurrence_count, 0) as actual_occurrence_count
    from expected_events as expected
    full outer join actual_event_counts as actual
        on expected.event_id = actual.event_id
    where
        expected.event_id is null
        or coalesce(actual.occurrence_count, 0) != expected.expected_occurrence_count
)

select * from partition_differences
