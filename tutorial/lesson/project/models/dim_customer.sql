{{ config(materialized='table') }}

-- STEP 5 — Publish the protected customer grain as a Layer3 dimension.
-- Build: dbt build --select +dim_customer --indirect-selection cautious
-- Intent: preserve one row per active customer_key without resolving readable identifiers.
-- Check: CUST-0001 matches Layer2 exactly and dim_customer contains 15 rows.

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
