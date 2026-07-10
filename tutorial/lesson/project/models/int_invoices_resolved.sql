{{ config(materialized='table') }}

select
    invoice_id,
    customer_ssn,
    service_id,
    amount,
    currency_code,
    issued_date,
    due_date,
    is_paid,
    paid_at,
    source_is_due,
    not is_paid and due_date <= date '2026-03-01' as is_due,
    source_updated_at
from {{ ref('int_invoice_resolution') }}
where resolution_status = 'ACCEPTED'
