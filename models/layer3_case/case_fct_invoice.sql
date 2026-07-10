{{ config(tags=['case_views']) }}

select
    invoices.invoice_key,
    invoices.customer_key,
    invoices.service_key,
    invoices.service_version_key,
    customers.full_name_key,
    customers.email_key,
    services.installation_address_key,
    invoices.issue_date_key,
    invoices.due_date_key,
    invoices.paid_date_key,
    invoices.amount,
    invoices.currency_code,
    invoices.is_paid,
    invoices.is_due,
    mapped_customers.full_name_value as full_name,
    mapped_customers.email_value as email,
    mapped_services.service_id_value as service_id,
    mapped_services.installation_address_value as installation_address
from {{ ref('fct_invoice') }} as invoices
inner join {{ ref('dim_customer') }} as customers
    on invoices.customer_key = customers.customer_key
inner join {{ ref('dim_service') }} as services
    on invoices.customer_key = services.customer_key
    and invoices.service_key = services.service_key
    and invoices.service_version_key = services.service_version_key
inner join {{ ref('fa_pd_customer') }} as mapped_customers
    on customers.customer_key = mapped_customers.customer_key
    and customers.full_name_key = mapped_customers.full_name_key
    and customers.email_key = mapped_customers.email_key
inner join {{ ref('fa_pd_service_address') }} as mapped_services
    on services.customer_key = mapped_services.customer_key
    and services.service_key = mapped_services.service_key
    and services.service_version_key = mapped_services.service_version_key
    and services.installation_address_key = mapped_services.installation_address_key
where {{ case_access_predicate() }}
