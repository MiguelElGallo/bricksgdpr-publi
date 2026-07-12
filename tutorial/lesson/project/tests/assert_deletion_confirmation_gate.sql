with metrics as (
    select
        (select count(*) from {{ ref('int_customer_deletion_requests') }}) as detected_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0095-D' and authorization_status = 'PENDING'
        ) as pending_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id in ('CCHG-0097-D', 'CCHG-0099-D')
                and authorization_status = 'AUTHORIZED'
        ) as authorized_count,
        (select count(*) from {{ ref('int_customer_deletion_plan') }}) as plan_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0095-D'
        ) as pending_plan_count,
        (
            select count(*) from {{ ref('int_current_customers') }}
            where customer_id = 'CUST-0095'
        ) as pending_customer_count,
        (
            select count(*) from {{ ref('int_current_customers') }}
            where customer_id in ('CUST-0097', 'CUST-0099')
        ) as authorized_customer_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0097-D'
                and deletion_mode = 'SPECIAL_DELETION'
        ) as special_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0099-D'
                and deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
        ) as full_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where
                deletion_request_id = 'CCHG-0097-D'
                and target_relation = 'int_invoices_resolved'
                and planned_action = 'REASSIGN_TO_ERASED_MEMBER'
        ) as special_invoice_action_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where
                deletion_request_id = 'CCHG-0099-D'
                and target_relation = 'int_invoices_resolved'
                and planned_action = 'DELETE_CURRENT_ROWS'
        ) as full_invoice_action_count
)

select *
from metrics
where
    detected_count != 3
    or pending_count != 1
    or authorized_count != 2
    or plan_count != 18
    or pending_plan_count != 0
    or pending_customer_count != 1
    or authorized_customer_count != 0
    or special_count != 1
    or full_count != 1
    or special_invoice_action_count != 1
    or full_invoice_action_count != 2
