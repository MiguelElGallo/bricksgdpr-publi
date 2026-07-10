{{ config(tags=['layer2_invoices', 'control_fixture', 'deletion_control']) }}

with fixture_metrics as (
    select
        (select count(*) from {{ ref('int_invoices_resolved') }}) as accepted_count,
        (select count(*) from {{ ref('quarantine_invoices') }}) as quarantine_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0098' and quarantine_reason = 'CUSTOMER_NOT_FOUND'
        ) as late_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where
                invoice_id in ('INV-0027', 'INV-0028')
                and quarantine_reason = 'SERVICE_INVALID'
        ) as invalid_service_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0026' and quarantine_reason = 'PAYMENT_DATE_UNEXPECTED'
        ) as unexpected_payment_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0101' and quarantine_reason = 'PAYMENT_DATE_MISSING'
        ) as missing_payment_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0102' and quarantine_reason = 'INVALID_INVOICE_DATE_RANGE'
        ) as invalid_invoice_period_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0103' and quarantine_reason = 'PAYMENT_BEFORE_ISSUE_DATE'
        ) as early_payment_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0104' and quarantine_reason = 'CUSTOMER_SERVICE_MISMATCH'
        ) as mismatch_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0105' and quarantine_reason = 'SERVICE_NOT_FOUND'
        ) as missing_service_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0107' and quarantine_reason = 'SERVICE_NOT_FOUND'
        ) as deleted_service_reference_count,
        (
            select count(*) from {{ ref('quarantine_invoices') }}
            where
                invoice_id = 'INV-0106'
                and quarantine_reason = 'SERVICE_NOT_VALID_ON_ISSUE_DATE'
        ) as out_of_period_count,
        (
            select count(*) from {{ ref('int_invoices_resolved') }}
            where invoice_id = 'INV-0002' and is_due and source_is_due
        ) as overdue_accepted_count,
        (
            select count(*) from {{ ref('int_invoices_resolved') }}
            where invoice_id = 'INV-0099'
        ) + (
            select count(*) from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0099'
        ) as deleted_output_count
)

select *
from fixture_metrics
where
    accepted_count != 25
    or quarantine_count != 11
    or late_count != 1
    or invalid_service_count != 2
    or unexpected_payment_count != 1
    or missing_payment_count != 1
    or invalid_invoice_period_count != 1
    or early_payment_count != 1
    or mismatch_count != 1
    or missing_service_count != 1
    or deleted_service_reference_count != 1
    or out_of_period_count != 1
    or overdue_accepted_count != 1
    or deleted_output_count != 0
