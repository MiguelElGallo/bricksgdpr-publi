{{ config(materialized='ephemeral', tags=['deletion_control', 'personal_data_control']) }}

-- This relation is the execution gate. A source tombstone alone is never sufficient:
-- a key appears here only after confirmation created an authorized all-relations plan.

select distinct customer_key
from {{ ref('int_customer_deletion_plan') }}
where plan_status = 'AUTHORIZED' and planned_action = 'DELETE_CURRENT_ROWS'
