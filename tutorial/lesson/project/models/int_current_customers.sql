{{ config(materialized='ephemeral') }}

select distinct customers.customer_ssn
from {{ ref('stg_customer') }} as customers
left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
    on customers.customer_ssn = deleted.customer_ssn
where
    customers.source_operation = 'UPSERT'
    and deleted.customer_ssn is null
