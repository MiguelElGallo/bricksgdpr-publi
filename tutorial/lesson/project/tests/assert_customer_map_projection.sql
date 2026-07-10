with differences as (
    select
        coalesce(mapped.customer_key, protected.customer_key) as customer_key,
        mapped.customer_key is null as missing_from_map,
        protected.customer_key is null as missing_from_protected,
        mapped.customer_pk_key is distinct from protected.customer_pk_key
            as customer_pk_key_changed,
        mapped.customer_id_key is distinct from protected.customer_id_key
            as customer_id_key_changed,
        mapped.first_name_key is distinct from protected.first_name_key as first_name_key_changed,
        mapped.last_name_key is distinct from protected.last_name_key as last_name_key_changed,
        mapped.full_name_key is distinct from protected.full_name_key as full_name_key_changed,
        mapped.email_key is distinct from protected.email_key as email_key_changed,
        mapped.phone_key is distinct from protected.phone_key as phone_key_changed,
        mapped.birth_date_key is distinct from protected.birth_date_key as birth_date_key_changed,
        mapped.address_key is distinct from protected.address_key as address_key_changed,
        mapped.customer_segment is distinct from protected.customer_segment as segment_changed,
        mapped.is_active is distinct from protected.is_active as active_state_changed,
        mapped.source_updated_at is distinct from protected.source_updated_at as timestamp_changed
    from {{ ref('demo_customer_map') }} as mapped
    full outer join {{ ref('int_customer_protected') }} as protected
        on mapped.customer_key = protected.customer_key
)

select *
from differences
where
    missing_from_map
    or missing_from_protected
    or customer_pk_key_changed
    or customer_id_key_changed
    or first_name_key_changed
    or last_name_key_changed
    or full_name_key_changed
    or email_key_changed
    or phone_key_changed
    or birth_date_key_changed
    or address_key_changed
    or segment_changed
    or active_state_changed
    or timestamp_changed
