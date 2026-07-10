with unpivoted_keys as (
    select
        mapped.customer_key as record_key,
        keys.key_name,
        keys.key_value
    from {{ ref('demo_customer_map') }} as mapped
    cross join lateral (
        values
            ('customer_key', mapped.customer_key),
            ('customer_pk_key', mapped.customer_pk_key),
            ('customer_id_key', mapped.customer_id_key),
            ('first_name_key', mapped.first_name_key),
            ('last_name_key', mapped.last_name_key),
            ('full_name_key', mapped.full_name_key),
            ('email_key', mapped.email_key),
            ('phone_key', mapped.phone_key),
            ('birth_date_key', mapped.birth_date_key),
            ('address_key', mapped.address_key)
    ) as keys(key_name, key_value)
),

violations as (
    select
        record_key,
        count(*) as key_count,
        count(distinct key_value) as distinct_key_count,
        count(*) filter (
            where
                key_value is null
                or not regexp_matches(key_value, '^demo-v1:[0-9a-f]{64}$')
        ) as invalid_key_count
    from unpivoted_keys
    group by record_key
)

select *
from violations
where key_count != 10 or distinct_key_count != 10 or invalid_key_count != 0
