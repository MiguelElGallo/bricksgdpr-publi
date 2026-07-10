{{ config(tags=['case_views']) }}

select
    customers.customer_key,
    customers.customer_id_key,
    customers.full_name_key,
    customers.email_key,
    customers.address_key,
    customers.customer_segment,
    customers.is_active,
    mapped.customer_id_value as customer_id,
    mapped.full_name_value as full_name,
    mapped.email_value as email,
    mapped.address_value as customer_address
from {{ ref('dim_customer') }} as customers
inner join {{ ref('fa_pd_customer') }} as mapped
    on customers.customer_key = mapped.customer_key
    and customers.customer_id_key = mapped.customer_id_key
    and customers.full_name_key = mapped.full_name_key
    and customers.email_key = mapped.email_key
    and customers.address_key = mapped.address_key
where {{ case_access_predicate() }}
