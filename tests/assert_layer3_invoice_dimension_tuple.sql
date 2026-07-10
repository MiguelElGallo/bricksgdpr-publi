{{ config(tags=['layer3_facts', 'personal_data_control']) }}

select
    invoices.invoice_key,
    invoices.customer_key,
    invoices.service_key,
    invoices.service_version_key
from {{ ref('fct_invoice') }} as invoices
left anti join {{ ref('dim_service') }} as services
    on invoices.customer_key = services.customer_key
    and invoices.service_key = services.service_key
    and invoices.service_version_key = services.service_version_key
