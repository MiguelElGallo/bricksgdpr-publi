{{ config(tags=['access_control', 'personal_data_control']) }}
{% set project = var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) %}
{% set evidence = var('evidence_catalog', env_var('DBT_EVIDENCE_CATALOG', project ~ '_evidence')) %}
-- None of the three data-consumer groups may inherit or hold raw evidence privileges.
select 'catalog' as boundary, grantee, privilege_type
from system.information_schema.catalog_privileges
where catalog_name = '{{ evidence | replace("'", "''") }}'
  and grantee in ('privacy_admins', 'restricted_users', 'case_users', 'account users', 'users')
union all
select 'schema', grantee, privilege_type
from system.information_schema.schema_privileges
where catalog_name = '{{ evidence | replace("'", "''") }}'
  and schema_name = 'deletion_control'
  and grantee in ('privacy_admins', 'restricted_users', 'case_users', 'account users', 'users')
union all
select 'table', grantee, privilege_type
from system.information_schema.table_privileges
where table_catalog = '{{ evidence | replace("'", "''") }}'
  and table_schema = 'deletion_control'
  and grantee in ('privacy_admins', 'restricted_users', 'case_users', 'account users', 'users')
