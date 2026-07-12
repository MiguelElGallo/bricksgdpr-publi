{{ config(materialized='view') }}

select
    trim(deletion_request_id) as deletion_request_id,
    upper(trim(decision_status)) as decision_status,
    cast(nullif(trim(decided_at), '') as timestamp) as decided_at,
    nullif(trim(decided_by_role), '') as decided_by_role,
    nullif(trim(decision_reason), '') as decision_reason,
    cast(legal_hold as boolean) as legal_hold
from {{ ref('customer_deletion_confirmations') }}
