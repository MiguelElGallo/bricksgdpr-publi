{{ config(materialized='view') }}

-- STEP 2 — Resolve one current active row per customer.
-- Build: dbt build --select +int_current_customers --indirect-selection cautious
-- Intent: rank UPSERTs newest-first, then exclude inactive and authorized deletion identities.
-- Check: CUST-0001 and pending CUST-0097 survive; the current-state view has 15 customers.

with ranked_upserts as (
    select
        customers.*,
        row_number() over (
            partition by customers.customer_id
            order by customers.source_updated_at desc, customers.customer_change_id desc
        ) as change_rank
    from {{ ref('stg_customer') }} as customers
    where customers.source_operation = 'UPSERT'
),

current_customers as (
    select upserts.*
    from ranked_upserts as upserts
    left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
        on upserts.customer_ssn = deleted.customer_ssn
    where
        upserts.change_rank = 1
        and upserts.is_active
        and deleted.customer_ssn is null
)

select
    customer_change_id,
    customer_pk,
    customer_id,
    customer_ssn,
    first_name,
    last_name,
    email,
    phone,
    birth_date,
    address_line1,
    address_line2,
    city,
    postal_code,
    country_code,
    customer_segment,
    is_active,
    source_operation,
    source_updated_at
from current_customers
