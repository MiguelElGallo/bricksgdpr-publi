{% macro bootstrap_project_catalog() %}
  {% if execute %}
    {% set catalog_name = adapter.quote(env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) %}
    {% do run_query('create catalog if not exists ' ~ catalog_name) %}
  {% endif %}
{% endmacro %}
