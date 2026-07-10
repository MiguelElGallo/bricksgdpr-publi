with fixture as (
    select
        quarantine.invoice_id,
        quarantine.service_id,
        quarantine.quarantine_reason,
        (
            select count(*)
            from {{ ref('int_invoices_resolved') }} as accepted
            where accepted.invoice_id = quarantine.invoice_id
        ) as accepted_rows
    from {{ ref('quarantine_invoices') }} as quarantine
    where quarantine.invoice_id = 'INV-0105'
)

select *
from fixture
where
    service_id != 'SVC-7777-A'
    or quarantine_reason != 'SERVICE_NOT_FOUND'
    or accepted_rows != 0

union all

select
    'MISSING' as invoice_id,
    'MISSING' as service_id,
    'MISSING' as quarantine_reason,
    -1 as accepted_rows
where not exists (select 1 from fixture)
