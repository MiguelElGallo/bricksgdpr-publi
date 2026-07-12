{{ config(tags=['deletion_control', 'control_fixture']) }}

with expected_targets as (
    select target_layer, target_relation, target_kind, planned_action
    from ({{ customer_deletion_target_relations() }})
),

expected_keys as (
    select distinct
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0099'
),

expected_plan as (
    select
        'CCHG-0099-D' as deletion_request_id,
        keys.customer_key,
        targets.target_layer,
        targets.target_relation,
        targets.target_kind,
        targets.planned_action
    from expected_keys as keys
    cross join expected_targets as targets
),

actual_plan as (
    select distinct
        deletion_request_id,
        customer_key,
        target_layer,
        target_relation,
        target_kind,
        planned_action
    from {{ ref('int_customer_deletion_plan') }}
),

missing_plan as (
    select * from expected_plan
    except
    select * from actual_plan
),

unexpected_plan as (
    select * from actual_plan
    except
    select * from expected_plan
),

metrics as (
    select
        (select count(*) from {{ ref('customer_deletion_requests') }}) as request_count,
        (
            select count(*) from {{ ref('customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0097-D' and authorization_status = 'PENDING'
        ) as pending_count,
        (
            select count(*) from {{ ref('customer_deletion_authorizations') }}
            where
                deletion_request_id = 'CCHG-0099-D'
                and decision_status = 'CONFIRMED'
                and authorization_status = 'AUTHORIZED'
                and not legal_hold
                and decided_at is not null
                and decided_by_role is not null
                and decision_reason is not null
        ) as authorized_count,
        (
            select count(distinct customer_key) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0099-D'
        ) as historical_key_count,
        (select count(*) from {{ ref('int_customer_deletion_plan') }}) as plan_row_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where target_kind = 'TABLE'
        ) as table_target_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where target_kind = 'VIEW'
        ) as view_target_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where planned_action = 'DELETE_CURRENT_ROWS'
        ) as delete_target_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where planned_action = 'REASSIGN_TO_ERASED_MEMBER'
        ) as reassign_target_count,
        (
            select count(distinct concat(target_layer, '.', target_relation))
            from {{ ref('int_customer_deletion_plan') }}
            where planned_action = 'EXCLUDE_ERASED_ROWS'
        ) as exclude_target_count,
        (select count(*) from missing_plan) as missing_plan_count,
        (select count(*) from unexpected_plan) as unexpected_plan_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0097-D'
        ) as pending_plan_count,
        (
            select count(*) from {{ ref('int_terminal_deleted_customer_keys') }}
        ) as suppression_key_count,
        (
            select count(distinct deletion_request_id)
            from {{ ref('int_terminal_deleted_customer_keys') }}
            where deletion_request_id = 'CCHG-0099-D'
        ) as suppression_request_count,
        (
            select count(*)
            from expected_keys
            where customer_key not in (
                select customer_key from {{ ref('int_terminal_deleted_customer_keys') }}
            )
        ) as missing_suppression_key_count,
        (
            select count(*)
            from {{ ref('int_terminal_deleted_customer_keys') }}
            where authorized_at is null or suppression_recorded_at is null
        ) as incomplete_suppression_evidence_count
)

select *
from metrics
where
    request_count != 2
    or pending_count != 1
    or authorized_count != 1
    or historical_key_count != 2
    or plan_row_count != 34
    or table_target_count != 13
    or view_target_count != 4
    or delete_target_count != 9
    or reassign_target_count != 4
    or exclude_target_count != 4
    or missing_plan_count != 0
    or unexpected_plan_count != 0
    or pending_plan_count != 0
    or suppression_key_count != 2
    or suppression_request_count != 1
    or missing_suppression_key_count != 0
    or incomplete_suppression_evidence_count != 0
