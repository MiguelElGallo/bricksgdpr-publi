{{ config(materialized='ephemeral', tags=['layer2_events']) }}

select
    event_id,
    {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
    event_type,
    occurred_at,
    measure_value,
    measure_unit,
    source_updated_at
from {{ ref('stg_customer_events') }}
