{{ config(tags=['layer3_facts', 'personal_data']) }}

select
    event_id as event_key,
    customer_key,
    cast(date_format(cast(occurred_at as date), 'yyyyMMdd') as int) as event_date_key,
    occurred_at,
    event_type,
    measure_value,
    measure_unit,
    source_updated_at
from {{ ref('int_customer_events_resolved') }}
