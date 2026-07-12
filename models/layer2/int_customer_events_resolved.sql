{{ config(tags=['layer2_events']) }}

select
    event_id,
    customer_key,
    event_type,
    occurred_at,
    measure_value,
    measure_unit,
    source_updated_at,
    is_erased_customer
from {{ ref('int_customer_event_resolution') }}
where resolution_status = 'ACCEPTED'
