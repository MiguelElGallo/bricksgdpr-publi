{{ config(materialized='ephemeral') }}

with nondeleted_invoices as (
    select invoices.*
    from {{ ref('stg_invoices') }} as invoices
    left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
        on invoices.customer_ssn = deleted.customer_ssn
    where deleted.customer_ssn is null
),

nondeleted_services as (
    select services.*
    from {{ ref('stg_customer_services') }} as services
    left join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
        on services.customer_ssn = deleted.customer_ssn
    where deleted.customer_ssn is null
),

service_stats as (
    select
        invoices.invoice_id,
        count(services.service_id) as service_period_count,
        count(*) filter (
            where services.customer_ssn = invoices.customer_ssn
        ) as customer_service_period_count,
        count(*) filter (
            where
                services.customer_ssn = invoices.customer_ssn
                and services.is_valid
                and services.valid_to >= services.valid_from
        ) as valid_service_period_count,
        count(*) filter (
            where
                services.customer_ssn = invoices.customer_ssn
                and services.is_valid
                and services.valid_to >= services.valid_from
                and invoices.issued_date between services.valid_from and services.valid_to
        ) as effective_service_period_count
    from nondeleted_invoices as invoices
    left join nondeleted_services as services
        on invoices.service_id = services.service_id
    group by invoices.invoice_id
)

select
    invoices.invoice_id,
    invoices.customer_ssn,
    invoices.service_id,
    invoices.amount,
    invoices.currency_code,
    invoices.issued_date,
    invoices.due_date,
    invoices.is_paid,
    invoices.paid_at,
    invoices.source_is_due,
    invoices.source_updated_at,
    case
        when customers.customer_ssn is null then 'CUSTOMER_NOT_FOUND'
        when stats.service_period_count = 0 then 'SERVICE_NOT_FOUND'
        when stats.customer_service_period_count = 0 then 'CUSTOMER_SERVICE_MISMATCH'
        when stats.valid_service_period_count = 0 then 'SERVICE_INVALID'
        when stats.effective_service_period_count = 0
            then 'SERVICE_NOT_VALID_ON_ISSUE_DATE'
        when stats.effective_service_period_count > 1
            then 'SERVICE_VERSION_AMBIGUOUS'
        when invoices.due_date < invoices.issued_date then 'INVALID_INVOICE_DATE_RANGE'
        when invoices.is_paid and invoices.paid_at is null then 'PAYMENT_DATE_MISSING'
        when not invoices.is_paid and invoices.paid_at is not null
            then 'PAYMENT_DATE_UNEXPECTED'
        when invoices.paid_at < invoices.issued_date then 'PAYMENT_BEFORE_ISSUE_DATE'
        else 'ACCEPTED'
    end as resolution_status
from nondeleted_invoices as invoices
inner join service_stats as stats
    on invoices.invoice_id = stats.invoice_id
left join {{ ref('int_current_customers') }} as customers
    on invoices.customer_ssn = customers.customer_ssn
