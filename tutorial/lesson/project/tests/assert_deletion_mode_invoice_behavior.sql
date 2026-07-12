with metrics as (
    select
        (
            select count(*)
            from {{ ref('int_invoices_resolved') }}
            where
                invoice_id = 'INV-0097'
                and customer_ssn = '-99999'
                and service_id = '-99999'
                and is_erased_customer
        ) as special_retained_count,
        (
            select count(*)
            from {{ ref('int_invoice_resolution') }}
            where invoice_id = 'INV-0099'
        ) as full_resolution_count,
        (
            select count(*)
            from {{ ref('int_invoices_resolved') }}
            where invoice_id = 'INV-0099'
        ) as full_resolved_count,
        (
            select count(*)
            from {{ ref('quarantine_invoices') }}
            where invoice_id = 'INV-0099'
        ) as full_quarantine_count
)

select *
from metrics
where
    special_retained_count != 1
    or full_resolution_count != 0
    or full_resolved_count != 0
    or full_quarantine_count != 0
