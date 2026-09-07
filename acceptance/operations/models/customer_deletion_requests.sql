{{ config(materialized='incremental', incremental_strategy='merge', unique_key='deletion_request_id') }}
-- An empty replay source must not erase the already archived request under --full-refresh.
select cast(null as string) as deletion_request_id,
       cast(null as string) as customer_id,
       cast(null as string) as customer_ssn,
       cast(null as timestamp) as source_deleted_at,
       cast(null as timestamp) as detected_at,
       cast(null as string) as detection_status
where false
