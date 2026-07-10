with source as (
    select * from {{ ref('customer') }}
),

typed as (
    select
        trim(customer_change_id) as customer_change_id,
        cast(customer_pk as bigint) as customer_pk,
        trim(customer_id) as customer_id,
        trim(customer_ssn) as customer_ssn,
        nullif(trim(first_name), '') as first_name,
        nullif(trim(last_name), '') as last_name,
        nullif(trim(email), '') as email,
        nullif(trim(phone), '') as phone,
        cast(nullif(trim(birth_date), '') as date) as birth_date,
        nullif(trim(address_line1), '') as address_line1,
        nullif(trim(address_line2), '') as address_line2,
        nullif(trim(city), '') as city,
        nullif(trim(postal_code), '') as postal_code,
        nullif(upper(trim(country_code)), '') as country_code,
        nullif(trim(customer_segment), '') as customer_segment,
        cast(is_active as boolean) as is_active,
        upper(trim(source_operation)) as source_operation,
        cast(source_updated_at as timestamp) as source_updated_at
    from source
)

select * from typed
