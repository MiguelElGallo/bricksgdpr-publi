{{ config(
    materialized='table',
    tags=['layer2_events', 'quarantine', 'personal_data'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'quarantine'
    }
) }}

with rejected_events as (
    select event_id, resolution_status
    from {{ ref('int_customer_event_resolution') }}
    where resolution_status != 'ACCEPTED'
)

select
    source.event_id,
    source.customer_ssn,
    source.event_type,
    source.occurred_at,
    source.measure_value,
    source.measure_unit,
    source.source_updated_at,
    rejected.resolution_status as quarantine_reason,
    current_timestamp() as quarantined_at
from {{ ref('stg_customer_events') }} as source
inner join rejected_events as rejected
    on source.event_id = rejected.event_id
