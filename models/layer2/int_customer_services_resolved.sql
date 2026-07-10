{{ config(tags=['layer2_services']) }}

select
    customer_key,
    service_key,
    service_version_key,
    installation_address_key,
    service_type,
    is_valid,
    valid_from,
    valid_to,
    source_updated_at
from {{ ref('int_customer_service_resolution') }}
where resolution_status = 'ACCEPTED'
