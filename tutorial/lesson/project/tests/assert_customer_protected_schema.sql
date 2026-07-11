{% set protected_relation = ref('int_customer_protected') %}

-- STEP 4 contract — Layer2 must expose exactly these 13 columns and no readable map values.
with expected_columns as (
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

actual_columns as (
    select column_name
    from information_schema.columns
    where
        table_schema = '{{ protected_relation.schema }}'
        and table_name = '{{ protected_relation.identifier }}'
),

schema_differences as (
    (
        select column_name from expected_columns
        except
        select column_name from actual_columns
    )
    union all
    (
        select column_name from actual_columns
        except
        select column_name from expected_columns
    )
)

select * from schema_differences
