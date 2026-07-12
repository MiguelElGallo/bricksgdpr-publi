{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='customer_key',
    on_schema_change='fail',
    tags=['deletion_control', 'personal_data_control']
) }}

-- One effective row per historical customer key. FULL_GOVERNED_OUTPUT_DELETION has higher
-- priority than SPECIAL_DELETION. Incremental runs may escalate but never downgrade a key.

with required_targets as (
    {{ customer_deletion_target_relations() }}
),

matching_plan_targets as (
    select
        plan.decision_revision_id,
        plan.deletion_request_id,
        plan.customer_key,
        plan.deletion_mode,
        plan.deletion_policy_version,
        min(plan.authorization_recorded_at) as authorization_recorded_at,
        min(plan.authorized_at) as authorized_at,
        count(distinct concat_ws(
            '|',
            plan.target_layer,
            plan.target_relation,
            plan.target_kind,
            plan.planned_action
        )) as matched_target_count
    from {{ ref('int_customer_deletion_plan') }} as plan
    inner join required_targets as targets
        on plan.target_layer = targets.target_layer
        and plan.target_relation = targets.target_relation
        and plan.target_kind = targets.target_kind
        and plan.planned_action = case plan.deletion_mode
            when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
            when 'SPECIAL_DELETION' then targets.special_deletion_action
        end
    where
        plan.plan_status = 'AUTHORIZED'
        and plan.deletion_mode in ('SPECIAL_DELETION', 'FULL_GOVERNED_OUTPUT_DELETION')
    group by
        plan.decision_revision_id,
        plan.deletion_request_id,
        plan.customer_key,
        plan.deletion_mode,
        plan.deletion_policy_version
),

required_target_count as (
    select count(*) as target_count
    from required_targets
),

complete_plans as (
    select plans.*
    from matching_plan_targets as plans
    cross join required_target_count as required
    where plans.matched_target_count = required.target_count
),

ranked_plans as (
    select
        plans.*,
        row_number() over (
            partition by plans.customer_key
            order by plans.authorization_recorded_at, plans.decision_revision_id
        ) as initial_rank,
        row_number() over (
            partition by plans.customer_key
            order by
                case plans.deletion_mode
                    when 'FULL_GOVERNED_OUTPUT_DELETION' then 0
                    else 1
                end,
                plans.authorization_recorded_at desc,
                plans.decision_revision_id desc
        ) as effective_rank
    from complete_plans as plans
),

initial_plans as (
    select * from ranked_plans where initial_rank = 1
),

effective_plans as (
    select * from ranked_plans where effective_rank = 1
),

candidate_state as (
    select
        effective.decision_revision_id,
        effective.deletion_request_id,
        effective.customer_key,
        effective.deletion_mode,
        effective.deletion_policy_version,
        effective.authorization_recorded_at,
        effective.authorized_at,
        initial.decision_revision_id as initial_decision_revision_id,
        initial.deletion_request_id as initial_deletion_request_id,
        initial.deletion_mode as initial_deletion_mode,
        initial.deletion_policy_version as initial_deletion_policy_version,
        initial.authorization_recorded_at as initial_authorization_recorded_at,
        initial.authorized_at as initial_authorized_at
    from effective_plans as effective
    inner join initial_plans as initial
        on effective.customer_key = initial.customer_key
),

{% if is_incremental() %}
existing_state as (
    select * from {{ this }}
),
{% endif %}

final_state as (
    select
        candidate.decision_revision_id,
        candidate.deletion_request_id,
        candidate.customer_key,
        candidate.deletion_mode,
        candidate.deletion_policy_version,
        candidate.authorization_recorded_at,
        candidate.authorized_at,
        {% if is_incremental() %}
        coalesce(existing.initial_decision_revision_id, candidate.initial_decision_revision_id)
            as initial_decision_revision_id,
        coalesce(existing.initial_deletion_request_id, candidate.initial_deletion_request_id)
            as initial_deletion_request_id,
        coalesce(existing.initial_deletion_mode, candidate.initial_deletion_mode)
            as initial_deletion_mode,
        coalesce(
            existing.initial_deletion_policy_version,
            candidate.initial_deletion_policy_version
        ) as initial_deletion_policy_version,
        coalesce(existing.initial_authorized_at, candidate.initial_authorized_at)
            as initial_authorized_at,
        coalesce(
            existing.initial_authorization_recorded_at,
            candidate.initial_authorization_recorded_at
        ) as initial_authorization_recorded_at,
        coalesce(existing.suppression_recorded_at, current_timestamp())
            as suppression_recorded_at,
        case
            when existing.customer_key is null
                and candidate.initial_deletion_mode = 'SPECIAL_DELETION'
                and candidate.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                then current_timestamp()
            when existing.deletion_mode = 'SPECIAL_DELETION'
                and candidate.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                then current_timestamp()
            else existing.mode_escalated_at
        end as mode_escalated_at
        {% else %}
        candidate.initial_decision_revision_id,
        candidate.initial_deletion_request_id,
        candidate.initial_deletion_mode,
        candidate.initial_deletion_policy_version,
        candidate.initial_authorized_at,
        candidate.initial_authorization_recorded_at,
        current_timestamp() as suppression_recorded_at,
        case
            when candidate.initial_deletion_mode = 'SPECIAL_DELETION'
                and candidate.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                then current_timestamp()
        end as mode_escalated_at
        {% endif %}
    from candidate_state as candidate
    {% if is_incremental() %}
    left join existing_state as existing
        on candidate.customer_key = existing.customer_key
    where
        existing.customer_key is null
        or (
            existing.deletion_mode = 'SPECIAL_DELETION'
            and candidate.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
        )
        or (
            existing.deletion_mode = candidate.deletion_mode
            and (
                candidate.authorization_recorded_at > existing.authorization_recorded_at
                or (
                    candidate.authorization_recorded_at = existing.authorization_recorded_at
                    and candidate.decision_revision_id > existing.decision_revision_id
                )
            )
        )
    {% endif %}
)

select
    decision_revision_id,
    deletion_request_id,
    customer_key,
    authorized_at,
    authorization_recorded_at,
    deletion_mode,
    deletion_policy_version,
    initial_decision_revision_id,
    initial_deletion_request_id,
    initial_deletion_mode,
    initial_deletion_policy_version,
    initial_authorized_at,
    initial_authorization_recorded_at,
    suppression_recorded_at,
    mode_escalated_at
from final_state
