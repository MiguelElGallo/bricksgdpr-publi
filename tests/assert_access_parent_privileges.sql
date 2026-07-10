{{ config(tags=['access_control', 'personal_data_control']) }}

{% set prefix = var('schema_prefix', '') | trim %}
{% set privacy = 'privacy_admins' %}
{% set restricted = 'restricted_users' %}
{% set case_users = 'case_users' %}
{% set schema_access = [
  (privacy, (prefix ~ '_layer1_source') if prefix else 'layer1_source'),
  (privacy, (prefix ~ '_layer1') if prefix else 'layer1'),
  (privacy, (prefix ~ '_priva_map') if prefix else 'priva_map'),
  (privacy, (prefix ~ '_layer2') if prefix else 'layer2'),
  (privacy, (prefix ~ '_layer3') if prefix else 'layer3'),
  (privacy, (prefix ~ '_layer3_case') if prefix else 'layer3_case'),
  (restricted, (prefix ~ '_priva_map') if prefix else 'priva_map'),
  (restricted, (prefix ~ '_layer2') if prefix else 'layer2'),
  (restricted, (prefix ~ '_layer3') if prefix else 'layer3'),
  (case_users, (prefix ~ '_layer3') if prefix else 'layer3'),
  (case_users, (prefix ~ '_layer3_case') if prefix else 'layer3_case')
] %}
{% set expected_rows = [] %}
{% for grantee, schema_name in schema_access %}
  {% do expected_rows.append(
    "select '" ~ grantee ~ "' as grantee, '" ~ schema_name ~ "' as schema_name"
  ) %}
{% endfor %}

with expected_schema_privileges as (
    {{ expected_rows | join('\n    union all\n    ') }}
),

actual_schema_privileges as (
    select distinct grantee, schema_name
    from system.information_schema.schema_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and privilege_type = 'USE_SCHEMA'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
),

schema_differences as (
    select
        coalesce(expected.grantee, actual.grantee) as grantee,
        coalesce(expected.schema_name, actual.schema_name) as schema_name,
        expected.grantee is null as is_unexpected,
        actual.grantee is null as is_missing
    from expected_schema_privileges as expected
    full outer join actual_schema_privileges as actual
        on expected.grantee = actual.grantee
        and expected.schema_name = actual.schema_name
    where expected.grantee is null or actual.grantee is null
),

catalog_differences as (
    select grantee, privilege_type as object_name
    from system.information_schema.catalog_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
        and privilege_type != 'USE_CATALOG'
),

expected_catalog_privileges as (
    select *
    from values ('{{ privacy }}'), ('{{ restricted }}'), ('{{ case_users }}')
        as expected(grantee)
),

actual_catalog_privileges as (
    select distinct grantee
    from system.information_schema.catalog_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and privilege_type = 'USE_CATALOG'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
),

catalog_use_differences as (
    select
        coalesce(expected.grantee, actual.grantee) as grantee,
        case
            when expected.grantee is null then 'UNEXPECTED_USE_CATALOG'
            else 'MISSING_USE_CATALOG'
        end as object_name
    from expected_catalog_privileges as expected
    full outer join actual_catalog_privileges as actual
        on expected.grantee = actual.grantee
    where expected.grantee is null or actual.grantee is null
),

unexpected_schema_privileges as (
    select grantee, concat(schema_name, ':', privilege_type) as object_name
    from system.information_schema.schema_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
        and privilege_type != 'USE_SCHEMA'
)

select 'schema' as object_type, grantee, schema_name as object_name
from schema_differences
union all
select 'catalog', grantee, object_name
from catalog_differences
union all
select 'catalog', grantee, object_name
from catalog_use_differences
union all
select 'schema_privilege', grantee, object_name
from unexpected_schema_privileges
