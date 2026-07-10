{{ config(materialized='table') }}

with raw_values as (
    select
        cast(customer_pk as varchar) as customer_pk_value,
        customer_id as customer_id_value,
        customer_ssn as customer_ssn_value,
        first_name as first_name_value,
        last_name as last_name_value,
        nullif(concat_ws(' ', first_name, last_name), '') as full_name_value,
        email as email_value,
        phone as phone_value,
        strftime(birth_date, '%Y-%m-%d') as birth_date_value,
        nullif(
            concat_ws(
                ', ',
                address_line1,
                address_line2,
                concat_ws(' ', postal_code, city),
                country_code
            ),
            ''
        ) as address_value,
        customer_segment,
        is_active,
        source_updated_at
    from {{ ref('int_current_customers') }}
)

select
    {{ demo_personal_data_key('customer_ssn_value', 'customer.ssn', 'ssn') }}
        as customer_key,
    {{ demo_personal_data_key('customer_pk_value', 'customer.source_pk') }}
        as customer_pk_key,
    {{ demo_personal_data_key('customer_id_value', 'customer.id') }} as customer_id_key,
    {{ demo_personal_data_key('first_name_value', 'customer.first_name') }} as first_name_key,
    {{ demo_personal_data_key('last_name_value', 'customer.last_name') }} as last_name_key,
    {{ demo_personal_data_key('full_name_value', 'customer.full_name') }} as full_name_key,
    {{ demo_personal_data_key('email_value', 'customer.email') }} as email_key,
    {{ demo_personal_data_key('phone_value', 'customer.phone', 'phone') }} as phone_key,
    {{ demo_personal_data_key('birth_date_value', 'customer.birth_date', 'date') }}
        as birth_date_key,
    {{ demo_personal_data_key('address_value', 'customer.address') }} as address_key,
    customer_pk_value,
    customer_id_value,
    customer_ssn_value,
    first_name_value,
    last_name_value,
    full_name_value,
    email_value,
    phone_value,
    birth_date_value,
    address_value,
    customer_segment,
    is_active,
    source_updated_at
from raw_values
