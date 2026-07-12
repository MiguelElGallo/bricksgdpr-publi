{{ config(tags=['access_control', 'personal_data_control']) }}

{% for relation_name in [
  'customer', 'customer_deletion_confirmations', 'customer_events', 'customer_services', 'invoices',
  'stg_customer', 'stg_customer_deletion_confirmations', 'stg_customer_events',
  'stg_customer_services', 'stg_invoices',
  'customer_deletion_requests', 'customer_deletion_authorization_history',
  'customer_deletion_authorizations',
  'quarantine_customer_events', 'quarantine_customer_services', 'quarantine_invoices',
  'fa_pd_customer', 'fa_pd_service_address',
  'int_customer_deletion_plan', 'int_terminal_deleted_customer_keys',
  'int_customer_protected', 'int_customer_events_resolved',
  'int_customer_services_resolved', 'int_invoices_resolved',
  'dim_customer', 'dim_service', 'dim_date', 'fct_customer_event', 'fct_invoice',
  'case_dim_customer', 'case_dim_service', 'case_fct_customer_event', 'case_fct_invoice'
] %}
  {% do ref(relation_name) %}
{% endfor %}

{% set prefix = var('schema_prefix', '') | trim %}
{% set privacy = 'privacy_admins' %}
{% set restricted = 'restricted_users' %}
{% set case_users = 'case_users' %}
{% set relation_sets = [
  ((prefix ~ '_layer1_source') if prefix else 'layer1_source',
   ['customer', 'customer_deletion_confirmations', 'customer_events', 'customer_services',
    'invoices'], [privacy]),
  ((prefix ~ '_layer1') if prefix else 'layer1',
   ['stg_customer', 'stg_customer_deletion_confirmations', 'stg_customer_events',
    'stg_customer_services', 'stg_invoices', 'customer_deletion_requests',
    'customer_deletion_authorization_history', 'customer_deletion_authorizations',
    'quarantine_customer_events', 'quarantine_customer_services', 'quarantine_invoices'],
   [privacy]),
  ((prefix ~ '_priva_map') if prefix else 'priva_map',
   ['fa_pd_customer', 'fa_pd_service_address'], [privacy, restricted]),
  ((prefix ~ '_layer2') if prefix else 'layer2',
   ['int_customer_protected', 'int_customer_events_resolved',
    'int_customer_services_resolved', 'int_invoices_resolved'], [privacy, restricted]),
  ((prefix ~ '_layer2') if prefix else 'layer2',
   ['int_customer_deletion_plan', 'int_terminal_deleted_customer_keys'], [privacy]),
  ((prefix ~ '_layer3') if prefix else 'layer3',
   ['dim_customer', 'dim_service', 'dim_date', 'fct_customer_event', 'fct_invoice'],
   [privacy, restricted]),
  ((prefix ~ '_layer3_case') if prefix else 'layer3_case',
   ['case_dim_customer', 'case_dim_service', 'case_fct_customer_event', 'case_fct_invoice'],
   [privacy, case_users])
] %}
{% set expected_rows = [] %}
{% for schema_name, relation_names, grantees in relation_sets %}
  {% for relation_name in relation_names %}
    {% for grantee in grantees %}
      {% do expected_rows.append(
        "select '" ~ grantee ~ "' as grantee, '" ~ schema_name
        ~ "' as table_schema, '" ~ relation_name ~ "' as table_name"
      ) %}
    {% endfor %}
  {% endfor %}
{% endfor %}

with expected_grants as (
    {{ expected_rows | join('\n    union all\n    ') }}
),

actual_grants as (
    select distinct grantee, table_schema, table_name
    from system.information_schema.table_privileges
    where
        table_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and privilege_type = 'SELECT'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
        and table_schema in (
            {% for schema_name, relation_names, grantees in relation_sets %}
            '{{ schema_name }}'{% if not loop.last %},{% endif %}
            {% endfor %}
        )
),

grant_differences as (
    select
        coalesce(expected.grantee, actual.grantee) as grantee,
        coalesce(expected.table_schema, actual.table_schema) as table_schema,
        coalesce(expected.table_name, actual.table_name) as table_name,
        expected.grantee is null as is_unexpected,
        actual.grantee is null as is_missing
    from expected_grants as expected
    full outer join actual_grants as actual
        on expected.grantee = actual.grantee
        and expected.table_schema = actual.table_schema
        and expected.table_name = actual.table_name
    where expected.grantee is null or actual.grantee is null
),

unexpected_relation_privileges as (
    select
        grantee,
        table_schema,
        concat(table_name, ':', privilege_type) as table_name,
        true as is_unexpected,
        false as is_missing
    from system.information_schema.table_privileges
    where
        table_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
        and privilege_type != 'SELECT'
        and table_schema in (
            {% for schema_name, relation_names, grantees in relation_sets %}
            '{{ schema_name }}'{% if not loop.last %},{% endif %}
            {% endfor %}
        )
)

select *
from grant_differences
union all
select *
from unexpected_relation_privileges
