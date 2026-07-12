{{ config(materialized='view') }}

select
    trim(decision_revision_id) as decision_revision_id,
    trim(deletion_request_id) as deletion_request_id,
    upper(trim(decision_status)) as decision_status,
    upper(trim(deletion_mode)) as deletion_mode,
    upper(trim(deletion_policy_version)) as deletion_policy_version,
    cast(nullif(trim(recorded_at), '') as timestamp) as recorded_at,
    cast(nullif(trim(decided_at), '') as timestamp) as decided_at,
    nullif(trim(decided_by_role), '') as decided_by_role,
    nullif(trim(decision_reason), '') as decision_reason,
    cast(legal_hold as boolean) as legal_hold
from {{ ref('customer_deletion_confirmations') }}
