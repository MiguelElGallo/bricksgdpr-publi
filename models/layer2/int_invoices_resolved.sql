{{ config(tags=['layer2_invoices']) }}

select
    invoice_id,
    case when is_erased_customer then {{ erased_member_key() }} else customer_key end as customer_key,
    case when is_erased_customer then {{ erased_member_key() }} else service_key end as service_key,
    case
        when is_erased_customer then {{ erased_member_key() }}
        else resolved_service_version_key
    end as service_version_key,
    amount,
    currency_code,
    issued_date,
    due_date,
    is_paid,
    paid_at,
    source_is_due,
    not is_paid and due_date <= cast('{{ var("as_of_date") }}' as date) as is_due,
    source_updated_at,
    is_erased_customer
from {{ ref('int_invoice_resolution') }}
where resolution_status = 'ACCEPTED'
