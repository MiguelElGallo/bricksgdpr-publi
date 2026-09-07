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
        ('case_dim_customer', '-99999'),
        ('case_dim_service', '-99999'),
        ('case_fct_customer_event', 'is_erased_customer'),
        ('case_fct_invoice', 'is_erased_customer')
        as expected(table_name, erased_filter_marker)
),

actual_relations as (
    select tables.table_name, tables.table_type, views.view_definition
    from system.information_schema.tables as tables
    left join system.information_schema.views as views
        on tables.table_catalog = views.table_catalog
        and tables.table_schema = views.table_schema
        and tables.table_name = views.table_name
    where
        tables.table_catalog = '{{ var("project_catalog", env_var("DBT_PROJECT_CATALOG", "bricksgdpr")) }}'
        and tables.table_schema = '{{ case_schema }}'
        and tables.table_name in (
            'case_dim_customer',
            'case_dim_service',
            'case_fct_customer_event',
            'case_fct_invoice'
        )
)

select
    coalesce(expected.table_name, actual.table_name) as table_name,
    actual.table_type,
    expected.erased_filter_marker
from expected_views as expected
full outer join actual_relations as actual
    on expected.table_name = actual.table_name
where
    expected.table_name is null
    or actual.table_name is null
    or actual.table_type != 'VIEW'
    or instr(lower(actual.view_definition), expected.erased_filter_marker) = 0
