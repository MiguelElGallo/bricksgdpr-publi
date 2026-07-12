{{ config(materialized='ephemeral', tags=['layer2_events']) }}

with classified_events as (
    select
        events.*,
        deletions.customer_key is not null as is_erased_customer
    from {{ ref('int_customer_events_keyed') }} as events
    left join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on events.customer_key = deletions.customer_key
)

select
    events.event_id,
    events.customer_key,
    events.event_type,
    events.occurred_at,
    events.measure_value,
    events.measure_unit,
    events.source_updated_at,
    events.is_erased_customer,
    case
        when events.is_erased_customer then 'ACCEPTED'
        when customers.customer_key is null then 'CUSTOMER_NOT_FOUND'
        else 'ACCEPTED'
    end as resolution_status
from classified_events as events
left join {{ ref('fa_pd_customer') }} as customers
    on events.customer_key = customers.customer_key
