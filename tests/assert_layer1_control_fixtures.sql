{{ config(tags=['layer1', 'control_fixture']) }}

with fixture_counts as (
    select
        (select count(*) from {{ ref('stg_customer') }} where customer_ssn = '900-00-0098')
            as late_customer_rows,
        (select count(*) from {{ ref('stg_customer_events') }} where customer_ssn = '900-00-0098')
            as late_event_rows,
        (select count(*) from {{ ref('stg_customer_services') }} where customer_ssn = '900-00-0098')
            as late_service_rows,
        (select count(*) from {{ ref('stg_invoices') }} where customer_ssn = '900-00-0098')
            as late_invoice_rows,
        (
            select count(*)
            from {{ ref('stg_customer_services') }}
            where valid_to < valid_from
        ) as invalid_service_rows,
        (
            select count(*)
            from {{ ref('stg_customer_services') }}
            where not is_valid
        ) as invalid_service_flag_rows,
        (
            select count(*)
            from {{ ref('stg_invoices') }}
            where not is_paid and paid_at is not null
        ) as inconsistent_payment_rows,
        (
            select count(*)
            from {{ ref('stg_invoices') }}
            where is_paid and paid_at is null
        ) as missing_payment_date_rows,
        (
            select count(*)
            from {{ ref('stg_invoices') }}
            where paid_at < issued_date
        ) as early_payment_rows,
        (
            select count(*)
            from {{ ref('stg_invoices') }}
            where due_date < issued_date
        ) as invalid_invoice_period_rows,
        (
            select count(*) from {{ ref('stg_customer_events') }} where customer_ssn = '900-00-0199'
        ) as deleted_event_rows,
        (
            select count(*) from {{ ref('stg_customer_services') }} where customer_ssn = '900-00-0199'
        ) as deleted_service_rows,
        (
            select count(*) from {{ ref('stg_invoices') }} where customer_ssn = '900-00-0199'
        ) as deleted_invoice_rows
)

select *
from fixture_counts
where
    late_customer_rows != 0
    or late_event_rows != 1
    or late_service_rows != 1
    or late_invoice_rows != 1
    or invalid_service_rows != 1
    or invalid_service_flag_rows != 1
    or inconsistent_payment_rows != 1
    or missing_payment_date_rows != 1
    or early_payment_rows != 1
    or invalid_invoice_period_rows != 1
    or deleted_event_rows != 1
    or deleted_service_rows != 1
    or deleted_invoice_rows != 1
