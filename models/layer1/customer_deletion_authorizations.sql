{{ config(
    materialized='table',
    tags=['deletion_control', 'personal_data_control'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'deletion_control'
    }
) }}

with ranked_history as (
    select
        history.*,
        row_number() over (
            partition by history.deletion_request_id
            order by history.recorded_at desc, history.decision_revision_id desc
        ) as revision_rank
    from {{ ref('customer_deletion_authorization_history') }} as history
)

select
    requests.deletion_request_id,
    requests.customer_id,
    requests.customer_ssn,
    requests.source_deleted_at,
    requests.detected_at,
    history.decision_revision_id,
    coalesce(history.decision_status, 'PENDING') as decision_status,
    history.deletion_mode,
    history.recorded_at,
    history.decided_at,
    history.decided_by_role,
    history.decision_reason,
    history.legal_hold,
    case
        when history.decision_revision_id is null then '{{ var("deletion_policy_version") }}'
        else history.deletion_policy_version
    end as deletion_policy_version,
    coalesce(history.authorization_status, 'PENDING') as authorization_status
from {{ ref('customer_deletion_requests') }} as requests
left join ranked_history as history
    on requests.deletion_request_id = history.deletion_request_id
    and history.revision_rank = 1
