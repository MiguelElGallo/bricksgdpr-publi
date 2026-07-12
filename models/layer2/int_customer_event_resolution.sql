{{ config(materialized='ephemeral', tags=['layer2_events']) }}

with mode_annotated_events as (
    {{ attach_customer_deletion_mode(
        source_relation=ref('int_customer_events_keyed'),
        customer_key_expression='source_rows.customer_key',
        output_columns=[
            'event_id', 'customer_key', 'event_type', 'occurred_at', 'measure_value',
            'measure_unit', 'source_updated_at'
        ],
        deletion_relation=ref('int_terminal_deleted_customer_keys')
    ) }}
),

classified_events as (
    select
        events.event_id,
        events.customer_key,
        events.event_type,
        events.occurred_at,
        events.measure_value,
        events.measure_unit,
        events.source_updated_at,
        events.deletion_mode,
        case
            when events.deletion_mode is not null then 'ACCEPTED'
            when customers.customer_key is null then 'CUSTOMER_NOT_FOUND'
            else 'ACCEPTED'
        end as resolution_status
    from mode_annotated_events as events
    left join {{ ref('fa_pd_customer') }} as customers
        on events.customer_key = customers.customer_key
)

{{ apply_customer_deletion_policy(
    source_relation='classified_events',
    output_columns=[
        'event_id', 'customer_key', 'event_type', 'occurred_at', 'measure_value',
        'measure_unit', 'source_updated_at', 'resolution_status'
    ],
    special_behavior='REPLACE',
    special_replacements={'customer_key': erased_member_key()},
    erased_flag_column='is_erased_customer'
) }}
