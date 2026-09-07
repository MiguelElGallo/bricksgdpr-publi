{{ config(tags=['layer2', 'personal_data_control']) }}

{% do ref('int_customer_protected') %}
{% do ref('int_customer_events_resolved') %}
{% do ref('int_customer_services_resolved') %}
{% do ref('int_invoices_resolved') %}

{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set layer2_schema = schema_prefix ~ '_layer2' if schema_prefix else 'layer2' %}

select table_name, column_name
from system.information_schema.columns
where
    table_catalog = '{{ var("project_catalog", env_var("DBT_PROJECT_CATALOG", "bricksgdpr")) }}'
    and table_schema = '{{ layer2_schema }}'
    and (
        (right(column_name, 6) = '_value' and column_name != 'measure_value')
        or column_name in (
            'customer_ssn',
            'customer_id',
            'first_name',
            'last_name',
            'full_name',
            'email',
            'phone',
            'birth_date',
            'address',
            'installation_address'
        )
    )
