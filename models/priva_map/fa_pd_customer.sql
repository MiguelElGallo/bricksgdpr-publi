with ranked_upserts as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by source_updated_at desc, customer_change_id desc
        ) as change_rank
    from {{ ref('stg_customer') }}
    where source_operation = 'UPSERT'
),

current_customers as (
    select upserts.*
    from ranked_upserts as upserts
    left anti join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on {{ personal_data_key('upserts.customer_ssn', 'customer.ssn', 'ssn') }}
            = deletions.customer_key
    where upserts.change_rank = 1 and upserts.is_active
),

raw_values as (
    select
        cast(customer_pk as string) as customer_pk_value,
        customer_id as customer_id_value,
        customer_ssn as customer_ssn_value,
        first_name as first_name_value,
        last_name as last_name_value,
        nullif(concat_ws(' ', first_name, last_name), '') as full_name_value,
        email as email_value,
        phone as phone_value,
        date_format(birth_date, 'yyyy-MM-dd') as birth_date_value,
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
    from current_customers
)

select
    {{ personal_data_key('customer_ssn_value', 'customer.ssn', 'ssn') }} as customer_key,
    {{ personal_data_key('customer_pk_value', 'customer.source_pk') }} as customer_pk_key,
    {{ personal_data_key('customer_id_value', 'customer.id') }} as customer_id_key,
    {{ personal_data_key('first_name_value', 'customer.first_name') }} as first_name_key,
    {{ personal_data_key('last_name_value', 'customer.last_name') }} as last_name_key,
    {{ personal_data_key('full_name_value', 'customer.full_name') }} as full_name_key,
    {{ personal_data_key('email_value', 'customer.email') }} as email_key,
    {{ personal_data_key('phone_value', 'customer.phone', 'phone') }} as phone_key,
    {{ personal_data_key('birth_date_value', 'customer.birth_date', 'date') }} as birth_date_key,
    {{ personal_data_key('address_value', 'customer.address') }} as address_key,
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
