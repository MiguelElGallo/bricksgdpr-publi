{{ config(materialized='ephemeral') }}

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
