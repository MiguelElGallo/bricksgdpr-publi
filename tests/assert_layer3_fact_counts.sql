{{ config(tags=['layer3_facts', 'control_fixture']) }}

with fact_counts as (
    select
        (select count(*) from {{ ref('fct_customer_event') }}) as event_count,
        (select count(*) from {{ ref('fct_invoice') }}) as invoice_count,
        (
            select count(*) from {{ ref('int_customer_events_resolved') }}
        ) as expected_event_count,
        (select count(*) from {{ ref('int_invoices_resolved') }}) as expected_invoice_count
)

select *
from fact_counts
where event_count != expected_event_count or invoice_count != expected_invoice_count
