{{ config(tags=['layer2_invoices']) }}

select invoice_id, is_paid, due_date, is_due
from {{ ref('int_invoices_resolved') }}
where
    is_due is distinct from (
        not is_paid and due_date <= cast('{{ var("as_of_date") }}' as date)
    )
