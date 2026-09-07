{% macro apply_access_controls() %}
  {% if execute %}
    {% set catalog = adapter.quote(var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr'))) %}
    {% set prefix = var('schema_prefix', '') | trim %}
    {% set privacy = '`privacy_admins`' %}
    {% set restricted = '`restricted_users`' %}
    {% set case_users = '`case_users`' %}
    {% set groups = [privacy, restricted, case_users] %}
    {% set schemas = {
      'layer1_source': (prefix ~ '_layer1_source') if prefix else 'layer1_source',
      'layer1': (prefix ~ '_layer1') if prefix else 'layer1',
      'priva_map': (prefix ~ '_priva_map') if prefix else 'priva_map',
      'layer2': (prefix ~ '_layer2') if prefix else 'layer2',
      'layer3': (prefix ~ '_layer3') if prefix else 'layer3',
      'layer3_case': (prefix ~ '_layer3_case') if prefix else 'layer3_case',
      'priva_internal': 'priva_internal'
    } %}

    {% for principal in groups %}
      {% do run_query('grant use catalog on catalog ' ~ catalog ~ ' to ' ~ principal) %}
      {% do run_query('revoke select on catalog ' ~ catalog ~ ' from ' ~ principal) %}
      {% do run_query('revoke execute on catalog ' ~ catalog ~ ' from ' ~ principal) %}
      {% do run_query(
        'revoke all privileges on schema '
        ~ catalog ~ '.' ~ adapter.quote(schemas['priva_internal'])
        ~ ' from ' ~ principal
      ) %}
      {% for function_name in [
        'hash_personal_data',
        'pseudonymize_personal_data_v1',
        'mask_priva_map_value'
      ] %}
        {% do run_query(
          'revoke execute on function '
          ~ catalog ~ '.' ~ adapter.quote(schemas['priva_internal'])
          ~ '.' ~ adapter.quote(function_name)
          ~ ' from ' ~ principal
        ) %}
      {% endfor %}
    {% endfor %}

    {% for schema_name in [
      schemas['layer1_source'],
      schemas['layer1'],
      schemas['priva_map'],
      schemas['layer2'],
      schemas['layer3'],
      schemas['layer3_case']
    ] %}
      {% do run_query(
        'grant use schema on schema ' ~ catalog ~ '.' ~ adapter.quote(schema_name)
        ~ ' to ' ~ privacy
      ) %}
    {% endfor %}

    {% for schema_name in [schemas['priva_map'], schemas['layer2'], schemas['layer3']] %}
      {% do run_query(
        'grant use schema on schema ' ~ catalog ~ '.' ~ adapter.quote(schema_name)
        ~ ' to ' ~ restricted
      ) %}
    {% endfor %}

    {% do run_query(
      'grant use schema on schema ' ~ catalog ~ '.' ~ adapter.quote(schemas['layer3_case'])
      ~ ' to ' ~ case_users
    ) %}

    {% for schema_name in [
      schemas['layer1_source'],
      schemas['layer1'],
      schemas['priva_map'],
      schemas['layer2'],
      schemas['layer3']
    ] %}
      {% do run_query(
        'revoke select on schema ' ~ catalog ~ '.' ~ adapter.quote(schema_name)
        ~ ' from ' ~ case_users
      ) %}
    {% endfor %}
    {% do run_query(
      'revoke use schema on schema ' ~ catalog ~ '.' ~ adapter.quote(schemas['layer3'])
      ~ ' from ' ~ case_users
    ) %}
    {% for table_name in [
      'dim_customer',
      'dim_service',
      'dim_date',
      'fct_customer_event',
      'fct_invoice'
    ] %}
      {% do run_query(
        'revoke select on table '
        ~ catalog ~ '.' ~ adapter.quote(schemas['layer3']) ~ '.' ~ adapter.quote(table_name)
        ~ ' from ' ~ case_users
      ) %}
    {% endfor %}
    {% do run_query(
      'revoke select on schema ' ~ catalog ~ '.' ~ adapter.quote(schemas['layer3_case'])
      ~ ' from ' ~ restricted
    ) %}

    {% for table_name in ['fa_pd_customer', 'fa_pd_service_address'] %}
      {% do run_query(
        'revoke select on table '
        ~ catalog ~ '.' ~ adapter.quote(schemas['priva_map']) ~ '.' ~ adapter.quote(table_name)
        ~ ' from ' ~ case_users
      ) %}
    {% endfor %}

    {% for view_name in [
      'case_dim_customer',
      'case_dim_service',
      'case_fct_customer_event',
      'case_fct_invoice'
    ] %}
      {% do run_query(
        'revoke select on view '
        ~ catalog ~ '.' ~ adapter.quote(schemas['layer3_case']) ~ '.' ~ adapter.quote(view_name)
        ~ ' from ' ~ restricted
      ) %}
    {% endfor %}
    {% do apply_deletion_evidence_access() %}
  {% endif %}
{% endmacro %}
