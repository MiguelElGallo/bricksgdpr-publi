with expected as (
    select invoices.invoice_id
    from {{ ref('stg_invoices') }} as invoices
    left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
        on invoices.customer_ssn = deleted.customer_ssn
    where deleted.customer_ssn is null
),

partitioned as (
    select invoice_id from {{ ref('int_invoices_resolved') }}
    union all
    select invoice_id from {{ ref('quarantine_invoices') }}
),

differences as (
    select
        coalesce(expected.invoice_id, partitioned.invoice_id) as invoice_id,
        count(expected.invoice_id) as expected_rows,
        count(partitioned.invoice_id) as actual_rows
    from expected
    full outer join partitioned
        on expected.invoice_id = partitioned.invoice_id
    group by coalesce(expected.invoice_id, partitioned.invoice_id)
)

select *
from differences
where expected_rows != 1 or actual_rows != 1
