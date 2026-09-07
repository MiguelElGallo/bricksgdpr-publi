{% macro bootstrap_project_catalog() %}
  {% if execute %}
    {% set catalog_name = adapter.quote(var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr'))) %}
    {% do run_query('create catalog if not exists ' ~ catalog_name) %}
    {% do bootstrap_deletion_evidence() %}
  {% endif %}
{% endmacro %}
