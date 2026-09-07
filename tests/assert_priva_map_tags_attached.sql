{{ config(tags=['priva_map', 'personal_data_control']) }}

{% do ref('fa_pd_customer') %}
{% do ref('fa_pd_service_address') %}
{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set priva_map_schema = schema_prefix ~ '_priva_map' if schema_prefix else 'priva_map' %}
{% set project_catalog = var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) %}

with expected_columns as (
    select *
    from values
        ('fa_pd_customer', 'customer_key', 'NATIONAL_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'customer_pk_key', 'SOURCE_RECORD_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'customer_id_key', 'CUSTOMER_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'first_name_key', 'NAME', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'last_name_key', 'NAME', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'full_name_key', 'NAME', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'email_key', 'EMAIL', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'phone_key', 'PHONE', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'birth_date_key', 'BIRTH_DATE', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'address_key', 'ADDRESS', 'PSEUDONYMIZED'),
        ('fa_pd_customer', 'customer_pk_value', 'SOURCE_RECORD_IDENTIFIER', 'RAW'),
        ('fa_pd_customer', 'customer_id_value', 'CUSTOMER_IDENTIFIER', 'RAW'),
        ('fa_pd_customer', 'customer_ssn_value', 'NATIONAL_IDENTIFIER', 'RAW'),
        ('fa_pd_customer', 'first_name_value', 'NAME', 'RAW'),
        ('fa_pd_customer', 'last_name_value', 'NAME', 'RAW'),
        ('fa_pd_customer', 'full_name_value', 'NAME', 'RAW'),
        ('fa_pd_customer', 'email_value', 'EMAIL', 'RAW'),
        ('fa_pd_customer', 'phone_value', 'PHONE', 'RAW'),
        ('fa_pd_customer', 'birth_date_value', 'BIRTH_DATE', 'RAW'),
        ('fa_pd_customer', 'address_value', 'ADDRESS', 'RAW'),
        ('fa_pd_service_address', 'customer_key', 'NATIONAL_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_service_address', 'service_key', 'SERVICE_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_service_address', 'service_version_key', 'SERVICE_IDENTIFIER', 'PSEUDONYMIZED'),
        ('fa_pd_service_address', 'installation_address_key', 'ADDRESS', 'PSEUDONYMIZED'),
        ('fa_pd_service_address', 'service_id_value', 'SERVICE_IDENTIFIER', 'RAW'),
        ('fa_pd_service_address', 'customer_ssn_value', 'NATIONAL_IDENTIFIER', 'RAW'),
        ('fa_pd_service_address', 'installation_address_value', 'ADDRESS', 'RAW')
        as expected(table_name, column_name, personal_data_category, personal_data_state)
),

expected_column_tags as (
    select
        table_name,
        column_name,
        'personal_data_category' as tag_name,
        personal_data_category as tag_value
    from expected_columns

    union all

    select table_name, column_name, 'personal_data_state', personal_data_state
    from expected_columns
),

actual_column_tags as (
    select table_name, column_name, tag_name, tag_value
    from {{ project_catalog }}.information_schema.column_tags
    where
        schema_name = '{{ priva_map_schema }}'
        and table_name in ('fa_pd_customer', 'fa_pd_service_address')
        and tag_name in ('personal_data_category', 'personal_data_state')
),

column_tag_differences as (
    select
        'column' as object_type,
        coalesce(expected.table_name, actual.table_name) as table_name,
        coalesce(expected.column_name, actual.column_name) as object_name,
        coalesce(expected.tag_name, actual.tag_name) as tag_name,
        expected.tag_value as expected_value,
        actual.tag_value as actual_value
    from expected_column_tags as expected
    full outer join actual_column_tags as actual
        on expected.table_name = actual.table_name
        and expected.column_name = actual.column_name
        and expected.tag_name = actual.tag_name
        and expected.tag_value = actual.tag_value
    where expected.table_name is null or actual.table_name is null
),

expected_table_tags as (
    select *
    from values
        ('fa_pd_customer', 'contains_personal_data', 'true'),
        ('fa_pd_customer', 'personal_data_area', 'priva_map'),
        ('fa_pd_service_address', 'contains_personal_data', 'true'),
        ('fa_pd_service_address', 'personal_data_area', 'priva_map')
        as expected(table_name, tag_name, tag_value)
),

actual_table_tags as (
    select table_name, tag_name, tag_value
    from {{ project_catalog }}.information_schema.table_tags
    where
        schema_name = '{{ priva_map_schema }}'
        and table_name in ('fa_pd_customer', 'fa_pd_service_address')
        and tag_name in ('contains_personal_data', 'personal_data_area')
),

table_tag_differences as (
    select
        'table' as object_type,
        coalesce(expected.table_name, actual.table_name) as table_name,
        coalesce(expected.table_name, actual.table_name) as object_name,
        coalesce(expected.tag_name, actual.tag_name) as tag_name,
        expected.tag_value as expected_value,
        actual.tag_value as actual_value
    from expected_table_tags as expected
    full outer join actual_table_tags as actual
        on expected.table_name = actual.table_name
        and expected.tag_name = actual.tag_name
        and expected.tag_value = actual.tag_value
    where expected.table_name is null or actual.table_name is null
)

select * from column_tag_differences
union all
select * from table_tag_differences
