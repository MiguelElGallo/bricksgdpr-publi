{{ config(tags=['layer3_facts', 'personal_data']) }}

select
    invoice_id as invoice_key,
    customer_key,
    service_key,
    service_version_key,
    cast(date_format(issued_date, 'yyyyMMdd') as int) as issue_date_key,
    cast(date_format(due_date, 'yyyyMMdd') as int) as due_date_key,
    cast(date_format(paid_at, 'yyyyMMdd') as int) as paid_date_key,
    amount,
    currency_code,
    is_paid,
    source_is_due,
    is_due,
    source_updated_at
from {{ ref('int_invoices_resolved') }}
