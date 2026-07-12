{{ config(materialized='table') }}

with rejected_invoices as (
    select invoice_id, resolution_status
    from {{ ref('int_invoice_resolution') }}
    where resolution_status != 'ACCEPTED' and not is_erased_customer
)

select
    source.invoice_id,
    source.customer_ssn,
    source.service_id,
    source.amount,
    source.currency_code,
    source.issued_date,
    source.due_date,
    source.is_paid,
    source.paid_at,
    source.source_is_due,
    source.source_updated_at,
    rejected.resolution_status as quarantine_reason,
    current_timestamp as quarantined_at
from {{ ref('stg_invoices') }} as source
inner join rejected_invoices as rejected
    on source.invoice_id = rejected.invoice_id
