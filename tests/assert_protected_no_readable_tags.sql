{{ config(tags=['layer2', 'layer3', 'personal_data_control']) }}

{% do ref('int_customer_protected') %}
{% do ref('int_customer_events_resolved') %}
{% do ref('int_customer_services_resolved') %}
{% do ref('int_invoices_resolved') %}
{% do ref('dim_customer') %}
{% do ref('dim_service') %}
{% do ref('dim_date') %}
{% do ref('fct_customer_event') %}
{% do ref('fct_invoice') %}

{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set layer2_schema = schema_prefix ~ '_layer2' if schema_prefix else 'layer2' %}
{% set layer3_schema = schema_prefix ~ '_layer3' if schema_prefix else 'layer3' %}
{% set project_catalog = env_var('DBT_PROJECT_CATALOG', 'bricksgdpr') %}

select schema_name, table_name, column_name, tag_value as personal_data_state
from {{ project_catalog }}.information_schema.column_tags
where
    schema_name in ('{{ layer2_schema }}', '{{ layer3_schema }}')
    and tag_name = 'personal_data_state'
    and tag_value in ('RAW', 'CONTROLLED_READABLE')
