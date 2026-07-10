with source as (
    select * from {{ ref('invoices') }}
),

typed as (
    select
        trim(invoice_id) as invoice_id,
        trim(customer_ssn) as customer_ssn,
        trim(service_id) as service_id,
        cast(amount as decimal(18, 2)) as amount,
        upper(trim(currency_code)) as currency_code,
        cast(issued_date as date) as issued_date,
        cast(due_date as date) as due_date,
        cast(is_paid as boolean) as is_paid,
        cast(nullif(trim(paid_at), '') as date) as paid_at,
        cast(is_due as boolean) as source_is_due,
        cast(source_updated_at as timestamp) as source_updated_at
    from source
)

select * from typed
