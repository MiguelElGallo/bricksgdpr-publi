with expected as (
    select
        invoices.invoice_id,
        case
            when deleted.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION' then 0
            else 1
        end as expected_rows
    from {{ ref('stg_invoices') }} as invoices
    left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
        on invoices.customer_ssn = deleted.customer_ssn
),

partitioned as (
    select invoice_id from {{ ref('int_invoices_resolved') }}
    union all
    select invoice_id from {{ ref('quarantine_invoices') }}
    union all
    select invoice_id
    from {{ ref('int_invoice_resolution') }}
    where is_erased_customer and resolution_status != 'ACCEPTED'
),

actual as (
    select invoice_id, count(*) as actual_rows
    from partitioned
    group by invoice_id
)

select
    coalesce(expected.invoice_id, actual.invoice_id) as invoice_id,
    expected.expected_rows,
    coalesce(actual.actual_rows, 0) as actual_rows
from expected
full outer join actual
    on expected.invoice_id = actual.invoice_id
where
    expected.invoice_id is null
    or coalesce(actual.actual_rows, 0) != expected.expected_rows
