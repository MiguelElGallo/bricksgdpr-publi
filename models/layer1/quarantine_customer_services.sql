{{ config(
    materialized='table',
    tags=['layer2_services', 'quarantine', 'personal_data'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'quarantine'
    }
) }}

with rejected_services as (
    select service_version_key, resolution_status
    from {{ ref('int_customer_service_resolution') }}
    where resolution_status != 'ACCEPTED'
),

keyed_source as (
    select
        source.*,
        {{ personal_data_key(
            "concat_ws('|', service_id, date_format(valid_from, 'yyyy-MM-dd'))",
            'service.version'
        ) }} as service_version_key
    from {{ ref('stg_customer_services') }} as source
)

select
    source.service_id,
    source.customer_ssn,
    source.service_type,
    source.installation_address_line1,
    source.installation_address_line2,
    source.installation_city,
    source.installation_postal_code,
    source.installation_country_code,
    source.is_valid,
    source.valid_from,
    source.valid_to,
    source.source_updated_at,
    rejected.resolution_status as quarantine_reason,
    current_timestamp() as quarantined_at
from keyed_source as source
inner join rejected_services as rejected
    on source.service_version_key = rejected.service_version_key
