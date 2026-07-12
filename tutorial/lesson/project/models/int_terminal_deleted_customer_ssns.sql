{{ config(materialized='ephemeral') }}

-- STEP 2 execution gate — only authorized plan rows become terminal deletion identifiers.

select distinct customer_ssn
from {{ ref('int_customer_deletion_plan') }}
where plan_status = 'AUTHORIZED' and planned_action = 'DELETE_CURRENT_ROWS'
