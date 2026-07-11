{{ config(materialized='table') }}

-- STEP 4 — Cross into the protected Layer2 teaching projection.
-- Build: dbt build --select +int_customer_protected --indirect-selection cautious
-- Intent: select keys and analytical attributes explicitly; no readable *_value column crosses.
-- Check: CUST-0001 keeps its demo keys in an exact 13-column, 14-row Layer2 table.

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
from {{ ref('demo_customer_map') }}
