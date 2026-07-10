{{ config(tags=['access_control', 'personal_data_control']) }}

{% set privacy = 'privacy_admins' %}
{% set restricted = 'restricted_users' %}
{% set case_users = 'case_users' %}

select grantee, specific_schema, specific_name, privilege_type, inherited_from
from system.information_schema.routine_privileges
where
    specific_catalog = '{{ env_var("DBT_PROJECT_CATALOG", "bricksgdpr") }}'
    and grantee in ('{{ privacy }}', '{{ restricted }}', '{{ case_users }}')
