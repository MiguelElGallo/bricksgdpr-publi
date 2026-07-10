with source_fixture as (
    select *
    from {{ ref('stg_customer') }}
    where
        customer_id = 'CUST-0001'
        and customer_ssn = '900-00-0001'
        and email = 'customer01@example.invalid'
        and source_operation = 'UPSERT'
),

current_fixture as (
    select *
    from {{ ref('int_current_customers') }}
    where
        customer_id = 'CUST-0001'
        and customer_ssn = '900-00-0001'
        and email = 'customer01@example.invalid'
        and customer_segment = 'small_business'
        and is_active
),

mapped_fixture as (
    select *
    from {{ ref('demo_customer_map') }}
    where
        customer_id_value = 'CUST-0001'
        and customer_key =
            'demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8'
        and email_key =
            'demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853'
        and customer_segment = 'small_business'
        and is_active
),

protected_fixture as (
    select *
    from {{ ref('int_customer_protected') }}
    where
        customer_key =
            'demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8'
        and email_key =
            'demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853'
        and customer_segment = 'small_business'
        and is_active
),

dimension_fixture as (
    select *
    from {{ ref('dim_customer') }}
    where
        customer_key =
            'demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8'
        and email_key =
            'demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853'
        and customer_segment = 'small_business'
        and is_active
),

domain_separation_probe as (
    select
        {{ demo_personal_data_key('source.email', 'customer.email') }} as email_domain_key,
        {{ demo_personal_data_key('source.email', 'customer.contact_email') }}
            as contact_email_domain_key
    from source_fixture as source
),

expected_protected_columns as (
    select column_name
    from (
        values
            ('customer_key'),
            ('customer_pk_key'),
            ('customer_id_key'),
            ('first_name_key'),
            ('last_name_key'),
            ('full_name_key'),
            ('email_key'),
            ('phone_key'),
            ('birth_date_key'),
            ('address_key'),
            ('customer_segment'),
            ('is_active'),
            ('source_updated_at')
    ) as expected(column_name)
),

protected_relations as (
    select relation_name
    from (
        values
            ('int_customer_protected'),
            ('dim_customer')
    ) as relations(relation_name)
),

expected_relation_columns as (
    select relations.relation_name, columns.column_name
    from protected_relations as relations
    cross join expected_protected_columns as columns
),

actual_relation_columns as (
    select table_name as relation_name, column_name
    from information_schema.columns
    where
        table_schema = 'main'
        and table_name in ('int_customer_protected', 'dim_customer')
),

protected_schema_differences as (
    select
        expected.relation_name,
        expected.column_name,
        'MISSING' as difference_type
    from expected_relation_columns as expected
    left join actual_relation_columns as actual
        on expected.relation_name = actual.relation_name
        and expected.column_name = actual.column_name
    where actual.column_name is null

    union all

    select
        actual.relation_name,
        actual.column_name,
        'EXTRA' as difference_type
    from actual_relation_columns as actual
    left join expected_relation_columns as expected
        on actual.relation_name = expected.relation_name
        and actual.column_name = expected.column_name
    where expected.column_name is null
),

fixture_metrics as (
    select
        (select count(*) from source_fixture) as source_fixture_count,
        (select count(*) from {{ ref('int_current_customers') }}) as current_customer_count,
        (select count(*) from current_fixture) as current_fixture_count,
        (select count(*) from {{ ref('demo_customer_map') }}) as mapped_customer_count,
        (select count(*) from mapped_fixture) as mapped_fixture_count,
        (select count(*) from {{ ref('int_customer_protected') }})
            as protected_customer_count,
        (select count(*) from protected_fixture) as protected_fixture_count,
        (select count(*) from {{ ref('dim_customer') }}) as dimension_customer_count,
        (select count(*) from dimension_fixture) as dimension_fixture_count,
        (
            select count(*)
            from mapped_fixture as mapped
            inner join protected_fixture as protected
                on mapped.customer_key = protected.customer_key
                and mapped.email_key = protected.email_key
            inner join dimension_fixture as dimension
                on protected.customer_key = dimension.customer_key
                and protected.email_key = dimension.email_key
        ) as propagated_fixture_count,
        (
            select count(*)
            from domain_separation_probe
            where
                email_domain_key is not null
                and contact_email_domain_key is not null
                and email_domain_key != contact_email_domain_key
        ) as domain_separated_count,
        (select count(*) from protected_schema_differences)
            as protected_schema_difference_count
)

select *
from fixture_metrics
where
    source_fixture_count != 1
    or current_customer_count != 14
    or current_fixture_count != 1
    or mapped_customer_count != 14
    or mapped_fixture_count != 1
    or protected_customer_count != 14
    or protected_fixture_count != 1
    or dimension_customer_count != 14
    or dimension_fixture_count != 1
    or propagated_fixture_count != 1
    or domain_separated_count != 1
    or protected_schema_difference_count != 0
