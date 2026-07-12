{{ config(tags=['deletion_control']) }}

with source_rows as (
    select *
    from values
        ('ordinary-row', 'ordinary-customer', 'ordinary-service'),
        ('special-row', 'special-customer', 'special-service'),
        ('full-row', 'full-customer', 'full-service')
        as source_rows(row_id, customer_key, service_key)
),

deletion_keys as (
    select *
    from values
        ('special-customer', 'SPECIAL_DELETION'),
        ('full-customer', 'FULL_GOVERNED_OUTPUT_DELETION')
        as deletion_keys(customer_key, deletion_mode)
),

generated_fact as (
    {{ generate_customer_deletion_model(
        model_name='generated_fact_example',
        model_type='FACT',
        source_relation='source_rows',
        primary_key='row_id',
        output_columns=['row_id', 'customer_key', 'service_key'],
        customer_key_column='customer_key',
        special_replacement_columns=['customer_key', 'service_key'],
        erased_flag_column='is_erased_customer',
        deletion_relation='deletion_keys'
    ) }}
),

generated_service as (
    {{ generate_customer_deletion_model(
        model_name='generated_service_example',
        model_type='SERVICE',
        source_relation='source_rows',
        primary_key='row_id',
        output_columns=['row_id', 'customer_key', 'service_key'],
        customer_key_column='customer_key',
        deletion_relation='deletion_keys'
    ) }}
),

raw_quarantine_rows as (
    select
        row_id,
        customer_key as customer_ssn,
        service_key as quarantine_reason
    from source_rows
),

generated_quarantine as (
    {{ generate_customer_deletion_model(
        model_name='generated_quarantine_example',
        model_type='QUARANTINE',
        source_relation='raw_quarantine_rows',
        primary_key='row_id',
        output_columns=['row_id', 'customer_ssn', 'quarantine_reason'],
        customer_key_column='customer_ssn',
        customer_key_expression='source_rows.customer_ssn',
        deletion_relation='deletion_keys'
    ) }}
),

policy_applied_source as (
    select * from generated_fact
    union all
    select
        'leaked-full-row' as row_id,
        'full-customer' as customer_key,
        'full-service' as service_key,
        false as is_erased_customer
),

generated_fact_projection as (
    {{ generate_customer_deletion_model(
        model_name='generated_fact_projection_example',
        model_type='FACT',
        source_relation='policy_applied_source',
        primary_key='row_id',
        output_columns=[
            'row_id', 'customer_key', 'service_key', 'is_erased_customer'
        ],
        customer_key_column='customer_key',
        special_replacement_columns=['customer_key', 'service_key'],
        erased_flag_column='is_erased_customer',
        deletion_relation='deletion_keys',
        source_is_policy_applied=true
    ) }}
),

generated_case_view as (
    {{ generate_customer_deletion_model(
        model_name='generated_case_example',
        model_type='CASE_VIEW',
        source_relation='generated_fact',
        primary_key='row_id',
        output_columns=['row_id', 'customer_key', 'service_key'],
        customer_key_column='customer_key',
        erased_flag_column='is_erased_customer',
        additional_predicate='true'
    ) }}
),

generated_targets as (
    {{ generate_customer_deletion_target_relations([
        {'target_layer': 'layer2', 'model_name': 'generated_fact_example', 'model_type': 'FACT'},
        {'target_layer': 'layer2', 'model_name': 'generated_service_example', 'model_type': 'SERVICE'},
        {'target_layer': 'layer3', 'model_name': 'generated_dimension_example', 'model_type': 'DIMENSION'},
        {'target_layer': 'priva_map', 'model_name': 'generated_mapping_example', 'model_type': 'MAPPING'},
        {'target_layer': 'layer1', 'model_name': 'generated_quarantine_example', 'model_type': 'QUARANTINE'},
        {'target_layer': 'layer2', 'model_name': 'generated_identity_example', 'model_type': 'IDENTITY'},
        {'target_layer': 'layer2', 'model_name': 'generated_dependent_example', 'model_type': 'DEPENDENT'},
        {'target_layer': 'layer3_case', 'model_name': 'generated_case_example', 'model_type': 'CASE_VIEW'}
    ]) }}
),

invalid_erased_fact as (
    select
        {{ erased_member_key() }} as customer_key,
        cast(null as string) as service_key,
        true as is_erased_customer
),

metrics as (
    select
        (select count(*) from generated_fact) as fact_count,
        (
            select count(*)
            from generated_fact
            where
                row_id = 'special-row'
                and customer_key = {{ erased_member_key() }}
                and service_key = {{ erased_member_key() }}
                and is_erased_customer
        ) as special_fact_count,
        (select count(*) from generated_fact where row_id = 'full-row') as full_fact_count,
        (select count(*) from generated_fact_projection) as fact_projection_count,
        (
            select count(*)
            from generated_fact_projection
            where
                row_id = 'special-row'
                and customer_key = {{ erased_member_key() }}
                and service_key = {{ erased_member_key() }}
                and is_erased_customer
        ) as projected_special_fact_count,
        (
            select count(*)
            from generated_fact_projection
            where row_id = 'leaked-full-row'
        ) as projected_full_leak_count,
        (
            select count(*)
            from invalid_erased_fact
            where
                is_erased_customer
                and (
                    not (customer_key <=> {{ erased_member_key() }})
                    or not (service_key <=> {{ erased_member_key() }})
                )
        ) as null_replacement_failure_count,
        (
            select count(*)
            from generated_service
            where row_id = 'ordinary-row'
        ) as ordinary_service_count,
        (select count(*) from generated_service) as service_count,
        (
            select count(*)
            from generated_quarantine
            where row_id = 'ordinary-row'
        ) as ordinary_quarantine_count,
        (select count(*) from generated_quarantine) as quarantine_count,
        (
            select count(*)
            from generated_case_view
            where row_id = 'ordinary-row'
        ) as ordinary_case_count,
        (select count(*) from generated_case_view) as case_count,
        (
            select count(*)
            from generated_targets
            where
                target_relation = 'generated_fact_example'
                and full_deletion_action = 'DELETE_CURRENT_ROWS'
                and special_deletion_action = 'REASSIGN_TO_ERASED_MEMBER'
        ) as fact_target_count,
        (
            select count(*)
            from generated_targets
            where
                target_relation = 'generated_service_example'
                and full_deletion_action = 'DELETE_CURRENT_ROWS'
                and special_deletion_action = 'DELETE_CURRENT_ROWS'
        ) as service_target_count,
        (
            select count(*)
            from generated_targets
            where
                target_relation = 'generated_case_example'
                and target_kind = 'VIEW'
                and full_deletion_action = 'EXCLUDE_DELETED_ROWS'
                and special_deletion_action = 'EXCLUDE_ERASED_ROWS'
        ) as case_target_count,
        (
            select count(*)
            from generated_targets
            where
                full_deletion_action = 'DELETE_CURRENT_ROWS'
                and special_deletion_action = 'DELETE_CURRENT_ROWS'
        ) as delete_style_target_count,
        (select count(*) from generated_targets) as target_count
)

select *
from metrics
where
    fact_count != 2
    or special_fact_count != 1
    or full_fact_count != 0
    or fact_projection_count != 2
    or projected_special_fact_count != 1
    or projected_full_leak_count != 0
    or null_replacement_failure_count != 1
    or ordinary_service_count != 1
    or service_count != 1
    or ordinary_quarantine_count != 1
    or quarantine_count != 1
    or ordinary_case_count != 1
    or case_count != 1
    or fact_target_count != 1
    or service_target_count != 1
    or case_target_count != 1
    or delete_style_target_count != 6
    or target_count != 8
