{{ config(tags=['layer2_invoices', 'personal_data_control']) }}

select
    invoices.invoice_id,
    invoices.customer_key,
    invoices.service_key,
    invoices.service_version_key
from {{ ref('int_invoices_resolved') }} as invoices
left anti join {{ ref('int_customer_services_resolved') }} as services
    on invoices.customer_key = services.customer_key
    and invoices.service_key = services.service_key
    and invoices.service_version_key = services.service_version_key
    and invoices.issued_date between services.valid_from and services.valid_to
