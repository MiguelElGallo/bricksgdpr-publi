{{ config(tags=['access_control', 'personal_data_control']) }}

with catalog_violations as (
    select 'catalog' as object_type, grantee, privilege_type, catalog_name as object_name
    from system.information_schema.catalog_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee not in ('privacy_admins', 'restricted_users', 'case_users', current_user())
),

schema_violations as (
    select 'schema' as object_type, grantee, privilege_type, schema_name as object_name
    from system.information_schema.schema_privileges
    where
        catalog_name = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee not in ('privacy_admins', 'restricted_users', 'case_users', current_user())
        and not (
            grantee = 'account users'
            and schema_name = 'information_schema'
            and privilege_type = 'USE_SCHEMA'
        )
),

relation_violations as (
    select
        'relation' as object_type,
        grantee,
        privilege_type,
        concat(table_schema, '.', table_name) as object_name
    from system.information_schema.table_privileges
    where
        table_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee not in ('privacy_admins', 'restricted_users', 'case_users', current_user())
        and not (
            grantee = 'account users'
            and table_schema = 'information_schema'
            and privilege_type = 'SELECT'
        )
),

routine_violations as (
    select
        'routine' as object_type,
        grantee,
        privilege_type,
        concat(specific_schema, '.', specific_name) as object_name
    from system.information_schema.routine_privileges
    where
        specific_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
        and grantee not in ('privacy_admins', 'restricted_users', 'case_users', current_user())
)

select * from catalog_violations
union all
select * from schema_violations
union all
select * from relation_violations
union all
select * from routine_violations
