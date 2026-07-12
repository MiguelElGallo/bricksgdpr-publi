{{ config(materialized='view') }}

with ranked_decisions as (
    select
        decisions.*,
        row_number() over (
            partition by deletion_request_id
            order by recorded_at desc, decision_revision_id desc
        ) as revision_rank
    from {{ ref('stg_customer_deletion_confirmations') }} as decisions
)

select
    requests.deletion_request_id,
    requests.customer_id,
    requests.customer_ssn,
    requests.source_deleted_at,
    decisions.decision_revision_id,
    coalesce(decisions.decision_status, 'PENDING') as decision_status,
    decisions.deletion_mode,
    decisions.deletion_policy_version,
    decisions.recorded_at,
    decisions.decided_at,
    decisions.legal_hold,
    case
        when decisions.decision_revision_id is null then 'PENDING'
        when decisions.legal_hold is null then 'INVALID'
        when decisions.legal_hold then 'HELD'
        when
            decisions.decision_status = 'CONFIRMED'
            and decisions.deletion_mode in (
                'SPECIAL_DELETION',
                'FULL_GOVERNED_OUTPUT_DELETION'
            )
            and decisions.deletion_policy_version = 'CUSTOMER_DELETION_V1'
            and decisions.recorded_at is not null
            and decisions.decided_at is not null
            and decisions.decided_by_role is not null
            and decisions.decision_reason is not null
            then 'AUTHORIZED'
        when decisions.decision_status = 'REJECTED' then 'REJECTED'
        else 'INVALID'
    end as authorization_status
from {{ ref('int_customer_deletion_requests') }} as requests
left join ranked_decisions as decisions
    on requests.deletion_request_id = decisions.deletion_request_id
    and decisions.revision_rank = 1
