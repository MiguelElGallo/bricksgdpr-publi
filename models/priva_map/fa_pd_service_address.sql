with service_values as (
    select
        service_id as service_id_value,
        customer_ssn as customer_ssn_value,
        nullif(
            concat_ws(
                ', ',
                installation_address_line1,
                installation_address_line2,
                concat_ws(' ', installation_postal_code, installation_city),
                installation_country_code
            ),
            ''
        ) as installation_address_value,
        service_type,
        is_valid,
        valid_from,
        valid_to,
        source_updated_at
    from {{ ref('stg_customer_services') }}
    where is_valid and valid_to >= valid_from
),

keyed_services as (
    select
        {{ personal_data_key('customer_ssn_value', 'customer.ssn', 'ssn') }} as customer_key,
        {{ personal_data_key('service_id_value', 'service.id') }} as service_key,
        {{ personal_data_key(
            "concat_ws('|', service_id_value, date_format(valid_from, 'yyyy-MM-dd'))",
            'service.version'
        ) }} as service_version_key,
        {{ personal_data_key(
            'installation_address_value',
            'service.installation_address'
        ) }} as installation_address_key,
        service_id_value,
        customer_ssn_value,
        installation_address_value,
        service_type,
        is_valid,
        valid_from,
        valid_to,
        source_updated_at
    from service_values
)

select
    services.customer_key,
    services.service_key,
    services.service_version_key,
    services.installation_address_key,
    services.service_id_value,
    services.customer_ssn_value,
    services.installation_address_value,
    services.service_type,
    services.is_valid,
    services.valid_from,
    services.valid_to,
    services.source_updated_at
from keyed_services as services
inner join {{ ref('fa_pd_customer') }} as customers
    on services.customer_key = customers.customer_key
