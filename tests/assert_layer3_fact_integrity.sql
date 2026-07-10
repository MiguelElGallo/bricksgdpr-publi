{{ config(tags=['layer3_facts', 'personal_data_control']) }}

with expected_events as (
    select
        event_id as event_key,
        customer_key,
        cast(date_format(cast(occurred_at as date), 'yyyyMMdd') as int) as event_date_key,
        occurred_at,
        event_type,
        measure_value,
        measure_unit,
        source_updated_at
    from {{ ref('int_customer_events_resolved') }}
),

event_differences as (
    (select * from {{ ref('fct_customer_event') }} except select * from expected_events)
    union all
    (select * from expected_events except select * from {{ ref('fct_customer_event') }})
),

expected_invoices as (
    select
        invoice_id as invoice_key,
        customer_key,
        service_key,
        service_version_key,
        cast(date_format(issued_date, 'yyyyMMdd') as int) as issue_date_key,
        cast(date_format(due_date, 'yyyyMMdd') as int) as due_date_key,
        cast(date_format(paid_at, 'yyyyMMdd') as int) as paid_date_key,
        amount,
        currency_code,
        is_paid,
        source_is_due,
        is_due,
        source_updated_at
    from {{ ref('int_invoices_resolved') }}
),

invoice_differences as (
    (select * from {{ ref('fct_invoice') }} except select * from expected_invoices)
    union all
    (select * from expected_invoices except select * from {{ ref('fct_invoice') }})
)

select 'event' as fact_name, event_key as record_key
from event_differences
union all
select 'invoice', invoice_key
from invoice_differences
