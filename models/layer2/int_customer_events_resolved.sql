{{ config(tags=['layer2_events']) }}

select
    event_id,
    case when is_erased_customer then {{ erased_member_key() }} else customer_key end as customer_key,
    event_type,
    occurred_at,
    measure_value,
    measure_unit,
    source_updated_at,
    is_erased_customer
from {{ ref('int_customer_event_resolution') }}
where resolution_status = 'ACCEPTED'
