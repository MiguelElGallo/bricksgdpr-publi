{{ config(materialized='ephemeral', tags=['deletion_control', 'personal_data_control']) }}

with deleted_customer_identities as (
    select distinct customer_id, customer_ssn
    from {{ ref('stg_customer') }}
    where source_operation = 'DELETE'
),

historical_deleted_customer_ssns as (
    select history.customer_ssn
    from {{ ref('stg_customer') }} as history
    inner join deleted_customer_identities as deletions
        on history.customer_id = deletions.customer_id

    union

    select customer_ssn
    from deleted_customer_identities
)

select distinct
    {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
from historical_deleted_customer_ssns
where customer_ssn is not null
