{{ config(tags=['deletion_control', 'control_fixture']) }}

with expected_targets as (
    select *
    from values
        ('layer1', 'quarantine_customer_events'),
        ('layer1', 'quarantine_customer_services'),
        ('layer1', 'quarantine_invoices'),
        ('priva_map', 'fa_pd_customer'),
        ('priva_map', 'fa_pd_service_address'),
        ('layer2', 'int_customer_protected'),
        ('layer2', 'int_customer_events_resolved'),
        ('layer2', 'int_customer_services_resolved'),
        ('layer2', 'int_invoices_resolved'),
        ('layer3', 'dim_customer'),
        ('layer3', 'dim_service'),
        ('layer3', 'fct_customer_event'),
        ('layer3', 'fct_invoice'),
        ('layer3_case', 'case_dim_customer'),
        ('layer3_case', 'case_dim_service'),
        ('layer3_case', 'case_fct_customer_event'),
        ('layer3_case', 'case_fct_invoice')
        as targets(target_layer, target_relation)
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
        targets.target_relation
    from expected_keys as keys
    cross join expected_targets as targets
),

actual_plan as (
    select distinct deletion_request_id, customer_key, target_layer, target_relation
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
        (select count(*) from missing_plan) as missing_plan_count,
        (select count(*) from unexpected_plan) as unexpected_plan_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0097-D'
        ) as pending_plan_count
)

select *
from metrics
where
    request_count != 2
    or pending_count != 1
    or authorized_count != 1
    or historical_key_count != 2
    or plan_row_count != 34
    or missing_plan_count != 0
    or unexpected_plan_count != 0
    or pending_plan_count != 0
