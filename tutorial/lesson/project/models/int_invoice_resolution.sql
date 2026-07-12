{{ config(materialized='ephemeral') }}

with mode_annotated_invoices as (
    {{ attach_customer_deletion_mode(
        source_relation=ref('stg_invoices'),
        customer_key_expression='source_rows.customer_ssn',
        output_columns=[
            'invoice_id', 'customer_ssn', 'service_id', 'amount', 'currency_code',
            'issued_date', 'due_date', 'is_paid', 'paid_at', 'source_is_due',
            'source_updated_at'
        ],
        deletion_relation=ref('int_terminal_deleted_customer_ssns')
    ) }}
),

mode_annotated_services as (
    {{ attach_customer_deletion_mode(
        source_relation=ref('stg_customer_services'),
        customer_key_expression='source_rows.customer_ssn',
        output_columns=[
            'service_id', 'customer_ssn', 'is_valid', 'valid_from', 'valid_to'
        ],
        deletion_relation=ref('int_terminal_deleted_customer_ssns')
    ) }}
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
    from mode_annotated_invoices as invoices
    left join mode_annotated_services as services
        on invoices.service_id = services.service_id
        and (invoices.deletion_mode is not null or services.deletion_mode is null)
    group by invoices.invoice_id
),

quality_classified_invoices as (
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
        invoices.deletion_mode,
        case
            when invoices.deletion_mode is null and customers.customer_ssn is null
                then 'CUSTOMER_NOT_FOUND'
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
    from mode_annotated_invoices as invoices
    inner join service_stats as stats
        on invoices.invoice_id = stats.invoice_id
    left join {{ ref('int_current_customers') }} as customers
        on invoices.customer_ssn = customers.customer_ssn
)

{{ apply_customer_deletion_policy(
    source_relation='quality_classified_invoices',
    output_columns=[
        'invoice_id', 'customer_ssn', 'service_id', 'amount', 'currency_code',
        'issued_date', 'due_date', 'is_paid', 'paid_at', 'source_is_due',
        'source_updated_at', 'resolution_status'
    ],
    special_behavior='REPLACE',
    special_replacements={
        'customer_ssn': "'-99999'",
        'service_id': "'-99999'"
    },
    erased_flag_column='is_erased_customer'
) }}
