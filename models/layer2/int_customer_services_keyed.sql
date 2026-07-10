{{ config(materialized='ephemeral', tags=['layer2_services']) }}

with source_values as (
    select
        service_id,
        customer_ssn,
        nullif(
            concat_ws(
                ', ',
                installation_address_line1,
                installation_address_line2,
                concat_ws(' ', installation_postal_code, installation_city),
                installation_country_code
            ),
            ''
        ) as installation_address,
        service_type,
        is_valid,
        valid_from,
        valid_to,
        source_updated_at
    from {{ ref('stg_customer_services') }}
)

select
    service_id,
    {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
    {{ personal_data_key('service_id', 'service.id') }} as service_key,
    {{ personal_data_key(
        "concat_ws('|', service_id, date_format(valid_from, 'yyyy-MM-dd'))",
        'service.version'
    ) }} as service_version_key,
    {{ personal_data_key(
        'installation_address',
        'service.installation_address'
    ) }} as installation_address_key,
    service_type,
    is_valid,
    valid_from,
    valid_to,
    source_updated_at
from source_values
