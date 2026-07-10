{% macro case_access_predicate() -%}
  (
    is_account_group_member(
      'case_users'
    )
    or is_account_group_member(
      'privacy_admins'
    )
  )
{%- endmacro %}
