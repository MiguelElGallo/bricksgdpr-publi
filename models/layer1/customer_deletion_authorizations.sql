{{ config(
    materialized='table',
    tags=['deletion_control', 'personal_data_control'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'deletion_control'
    }
) }}

select
    requests.deletion_request_id,
    requests.customer_id,
    requests.customer_ssn,
    requests.source_deleted_at,
    requests.detected_at,
    coalesce(decisions.decision_status, 'PENDING') as decision_status,
    decisions.decided_at,
    decisions.decided_by_role,
    decisions.decision_reason,
    coalesce(decisions.legal_hold, false) as legal_hold,
    case
        when coalesce(decisions.legal_hold, false) then 'HELD'
        when decisions.decision_status = 'CONFIRMED' then 'AUTHORIZED'
        when decisions.decision_status = 'REJECTED' then 'REJECTED'
        else 'PENDING'
    end as authorization_status
from {{ ref('customer_deletion_requests') }} as requests
left join {{ ref('stg_customer_deletion_confirmations') }} as decisions
    on requests.deletion_request_id = decisions.deletion_request_id
