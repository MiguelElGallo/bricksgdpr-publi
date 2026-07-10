{{ config(materialized='ephemeral', tags=['layer2_invoices']) }}

select
    invoice_id,
    {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
    {{ personal_data_key('service_id', 'service.id') }} as service_key,
    amount,
    currency_code,
    issued_date,
    due_date,
    is_paid,
    paid_at,
    is_due as source_is_due,
    source_updated_at
from {{ ref('stg_invoices') }}
