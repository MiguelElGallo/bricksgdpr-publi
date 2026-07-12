{{ config(tags=['layer2_invoices', 'deletion_control']) }}

with classified_invoices as (
    select invoice_id, resolution_status, is_erased_customer
    from {{ ref('int_invoice_resolution') }}
),

actual_invoice_counts as (
    select invoice_id, count(*) as occurrence_count
    from (
        select invoice_id from {{ ref('int_invoices_resolved') }}
        union all
        select invoice_id from {{ ref('quarantine_invoices') }}
        union all
        select invoice_id
        from classified_invoices
        where is_erased_customer and resolution_status != 'ACCEPTED'
    ) as outputs
    group by invoice_id
),

partition_differences as (
    select
        coalesce(expected.invoice_id, actual.invoice_id) as invoice_id,
        expected.invoice_id is not null as expected_to_exist,
        coalesce(actual.occurrence_count, 0) as occurrence_count
    from classified_invoices as expected
    full outer join actual_invoice_counts as actual
        on expected.invoice_id = actual.invoice_id
    where expected.invoice_id is null or coalesce(actual.occurrence_count, 0) != 1
)

select *
from partition_differences
