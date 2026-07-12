{{ config(materialized='ephemeral') }}

-- STEP 2 execution gate — only authorized plan rows become terminal deletion identifiers.

select distinct customer_ssn, deletion_mode
from {{ ref('int_customer_deletion_plan') }}
where plan_status = 'AUTHORIZED'
