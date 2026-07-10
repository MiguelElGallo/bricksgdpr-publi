{{ config(tags=['layer2_invoices']) }}

select
    invoice_id,
    customer_key,
    service_key,
    resolved_service_version_key as service_version_key,
    amount,
    currency_code,
    issued_date,
    due_date,
    is_paid,
    paid_at,
    source_is_due,
    not is_paid and due_date <= cast('{{ var("as_of_date") }}' as date) as is_due,
    source_updated_at
from {{ ref('int_invoice_resolution') }}
where resolution_status = 'ACCEPTED'
