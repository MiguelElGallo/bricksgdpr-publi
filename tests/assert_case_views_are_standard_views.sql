{{ config(tags=['case_views', 'personal_data_control']) }}

{% do ref('case_dim_customer') %}
{% do ref('case_dim_service') %}
{% do ref('case_fct_customer_event') %}
{% do ref('case_fct_invoice') %}

{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set case_schema = schema_prefix ~ '_layer3_case' if schema_prefix else 'layer3_case' %}

with expected_views as (
    select *
    from values
        ('case_dim_customer'),
        ('case_dim_service'),
        ('case_fct_customer_event'),
        ('case_fct_invoice')
        as expected(table_name)
),

actual_relations as (
    select table_name, table_type
    from system.information_schema.tables
    where
        table_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and table_schema = '{{ case_schema }}'
        and table_name in (
            'case_dim_customer',
            'case_dim_service',
            'case_fct_customer_event',
            'case_fct_invoice'
        )
)

select
    coalesce(expected.table_name, actual.table_name) as table_name,
    actual.table_type
from expected_views as expected
full outer join actual_relations as actual
    on expected.table_name = actual.table_name
where expected.table_name is null or actual.table_name is null or actual.table_type != 'VIEW'
