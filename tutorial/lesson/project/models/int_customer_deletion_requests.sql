{{ config(materialized='table') }}

-- Browser demo registry. The Databricks project uses an incremental ledger for ordinary runs.

select
    customer_change_id as deletion_request_id,
    customer_id,
    customer_ssn,
    source_updated_at as source_deleted_at,
    'DETECTED' as detection_status
from {{ ref('stg_customer') }}
where source_operation = 'DELETE'
