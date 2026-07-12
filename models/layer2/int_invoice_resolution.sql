{{ config(materialized='ephemeral', tags=['layer2_invoices']) }}

with classified_invoices as (
    select
        invoices.*,
        deletions.customer_key is not null as is_erased_customer
    from {{ ref('int_invoices_keyed') }} as invoices
    left join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on invoices.customer_key = deletions.customer_key
),

classified_services as (
    select
        services.*,
        deletions.customer_key is not null as is_erased_customer
    from {{ ref('int_customer_services_keyed') }} as services
    left join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on services.customer_key = deletions.customer_key
),

source_service_stats as (
    select
        invoices.invoice_id,
        count(services.service_key) as service_period_count,
        count_if(services.customer_key = invoices.customer_key) as customer_service_period_count,
        count_if(
            services.customer_key = invoices.customer_key
            and services.is_valid
            and services.valid_to >= services.valid_from
        ) as valid_service_period_count,
        count_if(
            services.customer_key = invoices.customer_key
            and services.is_valid
            and services.valid_to >= services.valid_from
            and invoices.issued_date between services.valid_from and services.valid_to
        ) as effective_service_period_count,
        max(
            case
                when
                    services.customer_key = invoices.customer_key
                    and services.is_valid
                    and services.valid_to >= services.valid_from
                    and invoices.issued_date between services.valid_from and services.valid_to
                    then services.service_version_key
            end
        ) as source_service_version_key
    from classified_invoices as invoices
    left join classified_services as services
        on invoices.service_key = services.service_key
        and (invoices.is_erased_customer or not services.is_erased_customer)
    group by invoices.invoice_id
),

mapped_service_stats as (
    select
        invoices.invoice_id,
        count(services.service_version_key) as mapped_service_period_count,
        max(services.service_version_key) as resolved_service_version_key
    from classified_invoices as invoices
    left join {{ ref('int_customer_services_resolved') }} as services
        on invoices.customer_key = services.customer_key
        and invoices.service_key = services.service_key
        and invoices.issued_date between services.valid_from and services.valid_to
    group by invoices.invoice_id
)

select
    invoices.invoice_id,
    invoices.customer_key,
    invoices.service_key,
    case
        when invoices.is_erased_customer then source_stats.source_service_version_key
        else mapped.resolved_service_version_key
    end as resolved_service_version_key,
    invoices.amount,
    invoices.currency_code,
    invoices.issued_date,
    invoices.due_date,
    invoices.is_paid,
    invoices.paid_at,
    invoices.source_is_due,
    invoices.source_updated_at,
    invoices.is_erased_customer,
    case
        when not invoices.is_erased_customer and customers.customer_key is null
            then 'CUSTOMER_NOT_FOUND'
        when source_stats.service_period_count = 0 then 'SERVICE_NOT_FOUND'
        when source_stats.customer_service_period_count = 0 then 'CUSTOMER_SERVICE_MISMATCH'
        when source_stats.valid_service_period_count = 0 then 'SERVICE_INVALID'
        when source_stats.effective_service_period_count = 0
            then 'SERVICE_NOT_VALID_ON_ISSUE_DATE'
        when source_stats.effective_service_period_count > 1
            then 'SERVICE_VERSION_AMBIGUOUS'
        when not invoices.is_erased_customer and mapped.mapped_service_period_count = 0
            then 'SERVICE_MAP_ENTRY_NOT_FOUND'
        when not invoices.is_erased_customer and mapped.mapped_service_period_count > 1
            then 'SERVICE_VERSION_AMBIGUOUS'
        when invoices.due_date < invoices.issued_date then 'INVALID_INVOICE_DATE_RANGE'
        when invoices.is_paid and invoices.paid_at is null then 'PAYMENT_DATE_MISSING'
        when not invoices.is_paid and invoices.paid_at is not null
            then 'PAYMENT_DATE_UNEXPECTED'
        when invoices.paid_at < invoices.issued_date then 'PAYMENT_BEFORE_ISSUE_DATE'
        else 'ACCEPTED'
    end as resolution_status
from classified_invoices as invoices
inner join source_service_stats as source_stats
    on invoices.invoice_id = source_stats.invoice_id
inner join mapped_service_stats as mapped
    on invoices.invoice_id = mapped.invoice_id
left join {{ ref('fa_pd_customer') }} as customers
    on invoices.customer_key = customers.customer_key
