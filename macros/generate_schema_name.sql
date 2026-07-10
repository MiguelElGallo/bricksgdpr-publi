{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- set schema_prefix = var('schema_prefix', '') | trim -%}
  {%- if custom_schema_name is none -%}
    {{ target.schema }}
  {%- elif node.resource_type == 'function' -%}
    {# Security functions stay in one stable internal schema inside the isolated catalog. #}
    {{ custom_schema_name | trim }}
  {%- elif schema_prefix -%}
    {{ schema_prefix }}_{{ custom_schema_name | trim }}
  {%- else -%}
    {{ custom_schema_name | trim }}
  {%- endif -%}
{%- endmacro %}
