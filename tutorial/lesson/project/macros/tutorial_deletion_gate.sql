{# One shared inventory: planning and execution must agree on every required target/action. #}
{% macro tutorial_deletion_targets() -%}
    select *
    from (
        values
            ('layer1', 'int_current_customers', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('priva_map', 'demo_customer_map', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('layer2', 'int_customer_protected', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            (
                'layer2', 'int_invoices_resolved',
                'DELETE_CURRENT_ROWS', 'REASSIGN_TO_ERASED_MEMBER'
            ),
            ('layer1', 'quarantine_invoices', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('layer3', 'dim_customer', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS')
    ) as target_relations(
        target_layer,
        target_relation,
        full_deletion_action,
        special_deletion_action
    )
{%- endmacro %}

{% macro tutorial_effective_deletion_modes(plan_relation) -%}
with required_targets as (
    {{ tutorial_deletion_targets() }}
),

complete_plans as (
    select
        plan.deletion_request_id,
        plan.customer_ssn,
        plan.deletion_mode
    from {{ plan_relation }} as plan
    inner join required_targets as targets
        on plan.target_layer = targets.target_layer
        and plan.target_relation = targets.target_relation
        and plan.planned_action = case plan.deletion_mode
            when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
            when 'SPECIAL_DELETION' then targets.special_deletion_action
        end
    where plan.plan_status = 'AUTHORIZED' and plan.customer_ssn is not null
    group by plan.deletion_request_id, plan.customer_ssn, plan.deletion_mode
    having count(distinct (plan.target_layer, plan.target_relation)) = (
        select count(*) from required_targets
    )
)

-- One effective mode prevents join fan-out. FULL wins across complete requests in this snapshot.
select
    customer_ssn,
    case
        when count(*) filter (where deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION') > 0
            then 'FULL_GOVERNED_OUTPUT_DELETION'
        else 'SPECIAL_DELETION'
    end as deletion_mode
from complete_plans
group by customer_ssn
{%- endmacro %}
