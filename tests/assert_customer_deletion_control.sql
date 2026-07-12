{{ config(tags=['deletion_control', 'control_fixture']) }}

with expected_targets as (
    select * from ({{ customer_deletion_target_relations() }})
),

authorized_key_revisions as (
    select distinct
        history.decision_revision_id,
        history.deletion_request_id,
        {{ personal_data_key('customers.customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
        history.deletion_mode,
        history.deletion_policy_version
    from {{ ref('customer_deletion_authorization_history') }} as history
    inner join {{ ref('stg_customer') }} as customers
        on history.customer_id = customers.customer_id
    where history.authorization_status = 'AUTHORIZED' and customers.customer_ssn is not null
),

expected_plan as (
    select
        revisions.decision_revision_id,
        revisions.deletion_request_id,
        revisions.customer_key,
        revisions.deletion_mode,
        revisions.deletion_policy_version,
        targets.target_layer,
        targets.target_relation,
        targets.target_kind,
        case revisions.deletion_mode
            when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
            when 'SPECIAL_DELETION' then targets.special_deletion_action
        end as planned_action
    from authorized_key_revisions as revisions
    cross join expected_targets as targets
),

actual_plan as (
    select distinct
        decision_revision_id,
        deletion_request_id,
        customer_key,
        deletion_mode,
        deletion_policy_version,
        target_layer,
        target_relation,
        target_kind,
        planned_action
    from {{ ref('int_customer_deletion_plan') }}
),

plan_differences as (
    (select 'MISSING' as difference_type, * from expected_plan
     except
     select 'MISSING', * from actual_plan)
    union all
    (select 'UNEXPECTED' as difference_type, * from actual_plan
     except
     select 'UNEXPECTED', * from expected_plan)
),

metrics as (
    select
        (select count(*) from {{ ref('customer_deletion_requests') }}) as request_count,
        (
            select count(*) from {{ ref('customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0095-D' and authorization_status = 'PENDING'
        ) as unconfirmed_pending_count,
        (
            select count(*) from {{ ref('customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0097-D'
                and authorization_status = 'AUTHORIZED'
                and deletion_mode = 'SPECIAL_DELETION'
        ) as current_special_count,
        (
            select count(*) from {{ ref('customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0099-D'
                and authorization_status = 'AUTHORIZED'
                and deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
        ) as current_full_count,
        (
            select count(*) from {{ ref('customer_deletion_authorization_history') }}
            where authorization_status = 'AUTHORIZED'
        ) as authorized_revision_count,
        (select count(*) from expected_plan) as expected_plan_count,
        (select count(*) from actual_plan) as actual_plan_count,
        (select count(*) from plan_differences) as plan_difference_count,
        (select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}) as ledger_key_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where deletion_mode = 'SPECIAL_DELETION' and deletion_request_id = 'CCHG-0097-D'
        ) as special_ledger_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                and deletion_request_id = 'CCHG-0099-D'
        ) as full_ledger_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where initial_deletion_mode = 'SPECIAL_DELETION'
        ) as initially_special_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                and initial_deletion_mode = 'SPECIAL_DELETION'
                and mode_escalated_at is not null
        ) as escalated_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where
                authorized_at is null
                or suppression_recorded_at is null
                or deletion_policy_version is null
                or decision_revision_id is null
                or initial_decision_revision_id is null
        ) as incomplete_evidence_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
            where
                decision_revision_id = 'DEC-0097-SPECIAL-REVIEW'
                and initial_decision_revision_id = 'DEC-0097-SPECIAL'
                and authorization_recorded_at = cast('2026-02-23 08:00:00' as timestamp)
                and initial_authorization_recorded_at = cast('2026-02-21 08:00:00' as timestamp)
        ) as same_mode_revision_update_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                and planned_action = 'DELETE_CURRENT_ROWS'
        ) as full_delete_targets,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
                and planned_action = 'EXCLUDE_DELETED_ROWS'
        ) as full_exclude_targets,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where deletion_mode = 'SPECIAL_DELETION'
                and planned_action = 'DELETE_CURRENT_ROWS'
        ) as special_delete_targets,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where deletion_mode = 'SPECIAL_DELETION'
                and planned_action = 'REASSIGN_TO_ERASED_MEMBER'
        ) as special_reassign_targets,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where deletion_mode = 'SPECIAL_DELETION'
                and planned_action = 'EXCLUDE_ERASED_ROWS'
        ) as special_exclude_targets
)

select *
from metrics
where
    request_count != 3
    or unconfirmed_pending_count != 1
    or current_special_count != 1
    or current_full_count != 1
    or authorized_revision_count != 4
    or expected_plan_count != 102
    or actual_plan_count != expected_plan_count
    or plan_difference_count != 0
    or ledger_key_count != 3
    or special_ledger_count != 1
    or full_ledger_count != 2
    or initially_special_count != 3
    or escalated_count != 2
    or incomplete_evidence_count != 0
    or same_mode_revision_update_count != 1
    or full_delete_targets != 13
    or full_exclude_targets != 4
    or special_delete_targets != 9
    or special_reassign_targets != 4
    or special_exclude_targets != 4
