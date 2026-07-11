{{ config(materialized='ephemeral') }}

-- STEP 2 support — turn every identifier ever used by a deleted customer into a tombstone.
-- A later UPSERT does not revive one of these historical identifiers in this teaching contract.

with deleted_customer_ids as (
    select distinct customer_id
    from {{ ref('stg_customer') }}
    where source_operation = 'DELETE'
),

historical_identifiers as (
    select distinct history.customer_ssn
    from {{ ref('stg_customer') }} as history
    inner join deleted_customer_ids as deleted
        on history.customer_id = deleted.customer_id
    where history.customer_ssn is not null
)

select customer_ssn from historical_identifiers
