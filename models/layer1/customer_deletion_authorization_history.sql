{{ config(
    materialized='table',
    tags=['deletion_control', 'personal_data_control'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'deletion_control'
    }
) }}

select
    decisions.decision_revision_id,
    requests.deletion_request_id,
    requests.customer_id,
    requests.customer_ssn,
    requests.source_deleted_at,
    requests.detected_at,
    decisions.decision_status,
    decisions.deletion_mode,
    decisions.recorded_at,
    decisions.decided_at,
    decisions.decided_by_role,
    decisions.decision_reason,
    decisions.legal_hold,
    decisions.deletion_policy_version,
    case
        when decisions.legal_hold is null then 'INVALID'
        when decisions.legal_hold then 'HELD'
        when
            decisions.decision_status = 'CONFIRMED'
            and decisions.deletion_mode in (
                'SPECIAL_DELETION',
                'FULL_GOVERNED_OUTPUT_DELETION'
            )
            and decisions.deletion_policy_version = '{{ var("deletion_policy_version") }}'
            and decisions.recorded_at is not null
            and decisions.decided_at is not null
            and decisions.decided_by_role is not null
            and decisions.decision_reason is not null
            then 'AUTHORIZED'
        when decisions.decision_status = 'CONFIRMED' then 'INVALID'
        when decisions.decision_status = 'REJECTED' then 'REJECTED'
        else 'PENDING'
    end as authorization_status
from {{ ref('customer_deletion_requests') }} as requests
inner join {{ ref('stg_customer_deletion_confirmations') }} as decisions
    on requests.deletion_request_id = decisions.deletion_request_id
