{{ config(tags=['layer3', 'personal_data_control']) }}

{% do ref('dim_customer') %}
{% do ref('dim_service') %}
{% do ref('dim_date') %}
{% do ref('fct_customer_event') %}
{% do ref('fct_invoice') %}

{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set layer3_schema = schema_prefix ~ '_layer3' if schema_prefix else 'layer3' %}

select table_name, column_name
from system.information_schema.columns
where
    table_catalog = '{{ var("project_catalog", env_var("DBT_PROJECT_CATALOG", "bricksgdpr")) }}'
    and table_schema = '{{ layer3_schema }}'
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
