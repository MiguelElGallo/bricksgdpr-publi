-- depends_on: {{ ref('int_customer_deletion_plan') }}
-- Adversarial plans: duplicated rows cannot stand in for missing targets; incomplete and
-- wrong-action plans must not execute. A complete FULL request wins over SPECIAL for one SSN.
with scenarios (deletion_request_id, customer_ssn, deletion_mode, scenario) as (
    values
        ('special', '900000001', 'SPECIAL_DELETION', 'complete'),
        ('full', '900000001', 'FULL_GOVERNED_OUTPUT_DELETION', 'complete'),
        ('missing', '900000002', 'FULL_GOVERNED_OUTPUT_DELETION', 'missing'),
        ('wrong', '900000003', 'SPECIAL_DELETION', 'wrong_action'),
        ('pending', '900000004', 'SPECIAL_DELETION', 'pending'),
        ('unknown', '900000005', 'UNKNOWN_MODE', 'complete'),
        ('special_only', '900000006', 'SPECIAL_DELETION', 'complete'),
        ('incomplete_escalation', '900000006', 'FULL_GOVERNED_OUTPUT_DELETION', 'missing'),
        ('split_first', '900000007', 'FULL_GOVERNED_OUTPUT_DELETION', 'split_first'),
        ('split_second', '900000007', 'FULL_GOVERNED_OUTPUT_DELETION', 'split_second')
),
required_targets as (
    {{ tutorial_deletion_targets() }}
),
plans as (
    select
        scenarios.deletion_request_id,
        scenarios.customer_ssn,
        scenarios.deletion_mode,
        targets.target_layer,
        targets.target_relation,
        case
            when scenario = 'wrong_action' and targets.target_relation = 'int_invoices_resolved'
                then 'DELETE_CURRENT_ROWS'
            when deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
            else targets.special_deletion_action
        end as planned_action,
        case when scenario = 'pending' then 'PENDING' else 'AUTHORIZED' end as plan_status
    from scenarios
    cross join required_targets as targets
    -- Deliberately duplicate every row to catch gates that count rows instead of unique targets.
    cross join (values (1), (2)) as duplicates(copy_number)
    where
        not (scenario = 'missing' and targets.target_relation = 'dim_customer')
        and not (scenario = 'split_first' and targets.target_layer != 'layer1')
        and not (scenario = 'split_second' and targets.target_layer = 'layer1')
),
actual as (
    {{ tutorial_effective_deletion_modes('plans') }}
),
expected (customer_ssn, deletion_mode) as (
    values
        ('900000001', 'FULL_GOVERNED_OUTPUT_DELETION'),
        ('900000006', 'SPECIAL_DELETION')
)
(select * from actual except all select * from expected)
union all
(select * from expected except all select * from actual)
