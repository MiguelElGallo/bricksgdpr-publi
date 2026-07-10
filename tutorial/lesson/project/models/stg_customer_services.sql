with source as (
    select * from {{ ref('customer_services') }}
),

typed as (
    select
        trim(service_id) as service_id,
        trim(customer_ssn) as customer_ssn,
        upper(trim(service_type)) as service_type,
        nullif(trim(installation_address_line1), '') as installation_address_line1,
        nullif(trim(installation_address_line2), '') as installation_address_line2,
        nullif(trim(installation_city), '') as installation_city,
        nullif(trim(installation_postal_code), '') as installation_postal_code,
        nullif(upper(trim(installation_country_code)), '') as installation_country_code,
        cast(is_valid as boolean) as is_valid,
        cast(valid_from as date) as valid_from,
        cast(valid_to as date) as valid_to,
        cast(source_updated_at as timestamp) as source_updated_at
    from source
)

select * from typed
