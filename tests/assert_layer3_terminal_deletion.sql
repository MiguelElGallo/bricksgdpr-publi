{{ config(tags=['layer3', 'deletion_control']) }}

with deleted_keys as (
    select customer_key from {{ ref('int_terminal_deleted_customer_keys') }}
),

matches as (
    select 'dim_customer' as relation_name, customer_key as record_key
    from {{ ref('dim_customer') }}
    where customer_key in (select customer_key from deleted_keys)

    union all

    select 'dim_service', service_version_key
    from {{ ref('dim_service') }}
    where customer_key in (select customer_key from deleted_keys)

    union all

    select 'fct_customer_event', event_key
    from {{ ref('fct_customer_event') }}
    where customer_key in (select customer_key from deleted_keys)

    union all

    select 'fct_invoice', invoice_key
    from {{ ref('fct_invoice') }}
    where customer_key in (select customer_key from deleted_keys)
)

select *
from matches
