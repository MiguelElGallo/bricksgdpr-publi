{{ config(tags=['layer3_dimensions']) }}

select
    customer_key,
    customer_pk_key,
    customer_id_key,
    first_name_key,
    last_name_key,
    full_name_key,
    email_key,
    phone_key,
    birth_date_key,
    address_key,
    customer_segment,
    is_active,
    source_updated_at
from {{ ref('int_customer_protected') }}
