{{ config(tags=['layer3_facts', 'personal_data']) }}

with projected_invoices as (
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
        source_updated_at,
        is_erased_customer
    from {{ ref('int_invoices_resolved') }}
)

{{ generate_customer_deletion_model(
    model_name='fct_invoice',
    model_type='FACT',
    source_relation='projected_invoices',
    primary_key='invoice_key',
    output_columns=[
        'invoice_key', 'customer_key', 'service_key', 'service_version_key',
        'issue_date_key', 'due_date_key', 'paid_date_key', 'amount', 'currency_code',
        'is_paid', 'source_is_due', 'is_due', 'source_updated_at', 'is_erased_customer'
    ],
    customer_key_column='customer_key',
    special_replacement_columns=[
        'customer_key', 'service_key', 'service_version_key'
    ],
    erased_flag_column='is_erased_customer',
    source_is_policy_applied=true
) }}
