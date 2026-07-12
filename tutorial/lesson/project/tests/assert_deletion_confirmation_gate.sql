with metrics as (
    select
        (select count(*) from {{ ref('int_customer_deletion_requests') }}) as detected_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0097-D' and authorization_status = 'PENDING'
        ) as pending_count,
        (
            select count(*) from {{ ref('int_customer_deletion_authorizations') }}
            where deletion_request_id = 'CCHG-0099-D' and authorization_status = 'AUTHORIZED'
        ) as authorized_count,
        (select count(*) from {{ ref('int_customer_deletion_plan') }}) as plan_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0097-D'
        ) as pending_plan_count,
        (
            select count(*) from {{ ref('int_current_customers') }}
            where customer_id = 'CUST-0097'
        ) as pending_customer_count,
        (
            select count(*) from {{ ref('int_current_customers') }}
            where customer_id = 'CUST-0099'
        ) as authorized_customer_count
)

select *
from metrics
where
    detected_count != 2
    or pending_count != 1
    or authorized_count != 1
    or plan_count != 12
    or pending_plan_count != 0
    or pending_customer_count != 1
    or authorized_customer_count != 0
