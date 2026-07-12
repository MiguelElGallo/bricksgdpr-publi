{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='customer_key',
    on_schema_change='fail',
    tags=['deletion_control', 'personal_data_control']
) }}

-- This durable suppression-admission ledger is also the downstream delete/reassignment gate. A source
-- tombstone alone is never sufficient: a key is first recorded only after an independently
-- confirmed, complete authorized plan exists. It does not claim that every downstream model
-- finished successfully. Ordinary incremental runs never remove an already recorded key.

with required_targets as (
    {{ customer_deletion_target_relations() }}
),

matching_plan_targets as (
    select
        plan.deletion_request_id,
        plan.customer_key,
        min(plan.authorized_at) as authorized_at,
        count(distinct concat_ws('|', plan.target_layer, plan.target_relation, plan.target_kind))
            as matched_target_count
    from {{ ref('int_customer_deletion_plan') }} as plan
    inner join required_targets as targets
        on plan.target_layer = targets.target_layer
        and plan.target_relation = targets.target_relation
        and plan.target_kind = targets.target_kind
        and plan.planned_action = targets.planned_action
    where plan.plan_status = 'AUTHORIZED'
    group by plan.deletion_request_id, plan.customer_key
),

required_target_count as (
    select count(*) as target_count
    from required_targets
),

complete_plans as (
    select
        plans.deletion_request_id,
        plans.customer_key,
        plans.authorized_at
    from matching_plan_targets as plans
    cross join required_target_count as required
    where plans.matched_target_count = required.target_count
),

first_complete_plan as (
    select
        deletion_request_id,
        customer_key,
        authorized_at,
        row_number() over (
            partition by customer_key
            order by authorized_at, deletion_request_id
        ) as admission_rank
    from complete_plans
)

select
    deletion_request_id,
    customer_key,
    authorized_at,
    current_timestamp() as suppression_recorded_at
from first_complete_plan
where admission_rank = 1
{% if is_incremental() %}
    and customer_key not in (select customer_key from {{ this }})
{% endif %}
