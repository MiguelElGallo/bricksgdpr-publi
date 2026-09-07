{{ config(tags=['priva_map', 'personal_data_control']) }}

{% do ref('fa_pd_customer') %}
{% do ref('fa_pd_service_address') %}
{% set schema_prefix = var('schema_prefix', '') | trim %}
{% set priva_map_schema = schema_prefix ~ '_priva_map' if schema_prefix else 'priva_map' %}
{% set project_catalog = var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) %}
{% set mask_name = project_catalog ~ '.priva_internal.mask_priva_map_value' %}

with expected_masks as (
    select *
    from values
        ('fa_pd_customer', 'customer_pk_value', '{{ mask_name }}', 'customer_pk_key'),
        ('fa_pd_customer', 'customer_id_value', '{{ mask_name }}', 'customer_id_key'),
        ('fa_pd_customer', 'customer_ssn_value', '{{ mask_name }}', 'customer_key'),
        ('fa_pd_customer', 'first_name_value', '{{ mask_name }}', 'first_name_key'),
        ('fa_pd_customer', 'last_name_value', '{{ mask_name }}', 'last_name_key'),
        ('fa_pd_customer', 'full_name_value', '{{ mask_name }}', 'full_name_key'),
        ('fa_pd_customer', 'email_value', '{{ mask_name }}', 'email_key'),
        ('fa_pd_customer', 'phone_value', '{{ mask_name }}', 'phone_key'),
        ('fa_pd_customer', 'birth_date_value', '{{ mask_name }}', 'birth_date_key'),
        ('fa_pd_customer', 'address_value', '{{ mask_name }}', 'address_key'),
        ('fa_pd_service_address', 'service_id_value', '{{ mask_name }}', 'service_key'),
        ('fa_pd_service_address', 'customer_ssn_value', '{{ mask_name }}', 'customer_key'),
        (
            'fa_pd_service_address',
            'installation_address_value',
            '{{ mask_name }}',
            'installation_address_key'
        )
        as expected(table_name, column_name, mask_name, using_columns)
),

actual_masks as (
    select table_name, column_name, mask_name, using_columns
    from system.information_schema.column_masks
    where
        table_catalog = '{{ project_catalog }}'
        and table_schema = '{{ priva_map_schema }}'
        and table_name in ('fa_pd_customer', 'fa_pd_service_address')
),

raw_tagged_columns as (
    select table_name, column_name
    from {{ project_catalog }}.information_schema.column_tags
    where
        schema_name = '{{ priva_map_schema }}'
        and table_name in ('fa_pd_customer', 'fa_pd_service_address')
        and tag_name = 'personal_data_state'
        and tag_value = 'RAW'
),

mask_differences as (
    select
        coalesce(expected.table_name, actual.table_name) as table_name,
        coalesce(expected.column_name, actual.column_name) as column_name,
        expected.mask_name as expected_mask_name,
        actual.mask_name as actual_mask_name,
        expected.using_columns as expected_using_columns,
        actual.using_columns as actual_using_columns
    from expected_masks as expected
    full outer join actual_masks as actual
        on expected.table_name = actual.table_name
        and expected.column_name = actual.column_name
        and expected.mask_name = actual.mask_name
        and expected.using_columns = actual.using_columns
    where expected.table_name is null or actual.table_name is null
),

raw_mask_differences as (
    select
        coalesce(raw_tags.table_name, masks.table_name) as table_name,
        coalesce(raw_tags.column_name, masks.column_name) as column_name,
        case when raw_tags.column_name is not null then 'RAW_TAG_REQUIRES_MASK' end
            as expected_mask_name,
        masks.mask_name as actual_mask_name,
        cast(null as string) as expected_using_columns,
        masks.using_columns as actual_using_columns
    from raw_tagged_columns as raw_tags
    full outer join actual_masks as masks
        on raw_tags.table_name = masks.table_name
        and raw_tags.column_name = masks.column_name
    where raw_tags.column_name is null or masks.column_name is null
)

select *
from mask_differences
union all
select *
from raw_mask_differences
