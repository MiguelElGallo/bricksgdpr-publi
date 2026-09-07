{{ config(tags=['generator_contract']) }}

{% set staging_spec = {
    'model_kind': 'STAGING',
    'model_name': 'stg_order_example',
    'description': 'Typed order fixture at one row per order.',
    'primary_key': 'order_id',
    'source_model': 'orders',
    'columns': [
        {
            'name': 'order_id',
            'expression': 'trim(source_rows.order_id)',
            'data_type': 'string',
            'description': 'Stable source order identifier.'
        },
        {
            'name': 'source_updated_at',
            'expression': 'cast(source_rows.source_updated_at as timestamp)',
            'data_type': 'timestamp',
            'description': 'Source update timestamp.'
        }
    ]
} %}

{% set quarantine_spec = {
    'model_kind': 'QUARANTINE',
    'model_name': 'quarantine_order_example',
    'description': 'Rejected readable order fixture at one row per order.',
    'primary_key': 'order_id',
    'source_model': 'stg_orders',
    'source_alias': 'orders',
    'columns': [
        {'name': 'order_id', 'expression': 'orders.order_id', 'data_type': 'string', 'description': 'Stable source order identifier.'},
        {'name': 'customer_ssn', 'expression': 'orders.customer_ssn', 'data_type': 'string', 'description': 'Readable remediation identifier.'},
        {'name': 'quarantine_reason', 'expression': 'rejected.resolution_status', 'data_type': 'string', 'description': 'Resolution failure reason.'}
    ],
    'joins': [
        {'model': 'int_order_resolution', 'alias': 'rejected', 'type': 'inner', 'on': 'orders.order_id = rejected.order_id'}
    ],
    'where': ["rejected.resolution_status != 'ACCEPTED'"],
    'deletion': {
        'model_type': 'QUARANTINE',
        'customer_key_column': 'customer_ssn',
        'customer_key_domain': 'customer.ssn',
        'customer_key_kind': 'ssn',
        'register_target': true
    }
} %}

{% set control_spec = {
    'model_kind': 'CONTROL',
    'model_name': 'customer_control_example',
    'description': 'Incremental control fixture at one row per decision.',
    'primary_key': 'decision_id',
    'source_cte': 'candidate_decisions',
    'materialized': 'incremental',
    'incremental': {'unique_key': 'decision_id', 'strategy': 'merge', 'on_schema_change': 'fail'},
    'ctes': [
        {'name': 'candidate_decisions', 'sql': "    select 'decision-1' as decision_id"}
    ],
    'columns': [
        {'name': 'decision_id', 'data_type': 'string', 'description': 'Stable decision identifier.'}
    ]
} %}

{% set mapping_spec = {
    'model_kind': 'MAPPING',
    'model_name': 'fa_pd_order_example',
    'description': 'Restricted order mapping fixture at one row per order.',
    'primary_key': 'order_key',
    'source_model': 'stg_orders',
    'columns': [
        {'name': 'order_key', 'key': {'expression': 'order_id', 'domain': 'order.id'}, 'data_type': 'string', 'description': 'Pseudonymous order key.'},
        {'name': 'customer_key', 'key': {'expression': 'customer_ssn', 'domain': 'customer.ssn', 'kind': 'ssn'}, 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {
            'name': 'order_id_value',
            'expression': 'source_rows.order_id',
            'data_type': 'string',
            'description': 'Readable order identifier inside priva_map.',
            'databricks_tags': {
                'personal_data_category': 'ORDER_IDENTIFIER',
                'personal_data_state': 'RAW'
            },
            'column_mask': {
                'function': "{{ var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) }}.priva_internal.mask_priva_map_value",
                'using_columns': 'order_key'
            }
        }
    ],
    'deletion': {'model_type': 'MAPPING', 'customer_key_column': 'customer_key', 'register_target': true}
} %}

{% set layer2_control_spec = {
    'model_kind': 'CONTROL',
    'model_name': 'layer2_control_example',
    'description': 'Layer2 control fixture at one row per protected key.',
    'primary_key': 'customer_key',
    'source_model': 'int_customer_protected',
    'columns': [
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Protected customer key.'}
    ]
} %}

{% set keyed_spec = {
    'model_kind': 'KEYED',
    'model_name': 'int_orders_keyed_example',
    'description': 'Pseudonymized order fixture at one row per order.',
    'primary_key': 'order_id',
    'source_model': 'stg_orders',
    'columns': [
        {'name': 'order_id', 'data_type': 'string', 'description': 'Stable order identifier.'},
        {'name': 'customer_key', 'key': {'expression': 'customer_ssn', 'domain': 'customer.ssn', 'kind': 'ssn'}, 'data_type': 'string', 'description': 'Pseudonymous customer key.'}
    ]
} %}

{% set resolution_spec = {
    'model_kind': 'RESOLUTION',
    'model_name': 'int_order_resolution_example',
    'description': 'Resolution fixture at one row per order.',
    'primary_key': 'order_id',
    'source_cte': 'classified_orders',
    'ctes': [
        {'name': 'classified_orders', 'sql': "    select order_id, customer_key, deletion_mode, 'ACCEPTED' as resolution_status from {{ ref('int_orders_keyed') }}"}
    ],
    'columns': [
        {'name': 'order_id', 'data_type': 'string', 'description': 'Stable order identifier.'},
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {'name': 'resolution_status', 'data_type': 'string', 'description': 'Resolution outcome.'},
        {'name': 'is_erased_customer', 'data_type': 'boolean', 'description': 'Whether SPECIAL retained the row under the erased member.'}
    ],
    'helper_columns': [
        {'name': 'deletion_mode'}
    ],
    'deletion': {
        'model_type': 'FACT',
        'customer_key_column': 'customer_key',
        'special_replacement_columns': ['customer_key'],
        'erased_flag_column': 'is_erased_customer',
        'source_is_mode_annotated': true
    }
} %}

{% set published_spec = {
    'model_kind': 'PUBLISHED',
    'model_name': 'int_orders_resolved_example',
    'description': 'Accepted order fixture at one row per order.',
    'primary_key': 'order_id',
    'source_model': 'int_order_resolution',
    'columns': [
        {'name': 'order_id', 'data_type': 'string', 'description': 'Stable order identifier.'},
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'}
    ],
    'where': ["source_rows.resolution_status = 'ACCEPTED'"]
} %}

{% set dimension_spec = {
    'model_kind': 'DIMENSION',
    'model_name': 'dim_order_example',
    'description': 'Order dimension fixture plus one erased member.',
    'primary_key': 'order_key',
    'source_model': 'int_orders_resolved',
    'columns': [
        {'name': 'order_key', 'data_type': 'string', 'description': 'Stable order dimension key.'},
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {'name': 'order_status', 'data_type': 'string', 'description': 'Current order status.'}
    ],
    'erased_member': {
        'order_key': '{{ erased_member_key() }}',
        'customer_key': '{{ erased_member_key() }}',
        'order_status': "'ERASED_SUBJECT'"
    },
    'deletion': {
        'model_type': 'DIMENSION',
        'customer_key_column': 'customer_key',
        'register_target': true
    }
} %}

{% set date_spec = {
    'model_kind': 'DATE_DIMENSION',
    'model_name': 'dim_date_example',
    'description': 'Conformed date fixture for the configured inclusive range.'
} %}

{% set fresh_fact_spec = {
    'model_kind': 'FACT',
    'model_name': 'fct_fresh_order_example',
    'description': 'Fresh deletion-aware order fact fixture.',
    'primary_key': 'order_key',
    'source_model': 'int_orders_classified',
    'columns': [
        {'name': 'order_key', 'data_type': 'string', 'description': 'Stable order fact key.'},
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {'name': 'is_erased_customer', 'data_type': 'boolean', 'description': 'Whether SPECIAL retained the fact under the erased member.'}
    ],
    'deletion': {
        'model_type': 'FACT',
        'customer_key_column': 'customer_key',
        'special_replacement_columns': ['customer_key'],
        'erased_flag_column': 'is_erased_customer'
    }
} %}

{% set fact_spec = {
    'model_kind': 'FACT',
    'model_name': 'fct_order_example',
    'description': 'Order fact fixture at one row per order.',
    'primary_key': 'order_key',
    'source_model': 'int_orders_resolved',
    'columns': [
        {'name': 'order_key', 'expression': 'source_rows.order_id', 'data_type': 'string', 'description': 'Stable order fact key.'},
        {'name': 'customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {'name': 'is_erased_customer', 'data_type': 'boolean', 'description': 'Whether the fact uses the erased member.'}
    ],
    'deletion': {
        'model_type': 'FACT',
        'customer_key_column': 'customer_key',
        'special_replacement_columns': ['customer_key'],
        'erased_flag_column': 'is_erased_customer',
        'source_is_policy_applied': true,
        'register_target': true
    }
} %}

{% set case_spec = {
    'model_kind': 'CASE_VIEW',
    'model_name': 'case_fct_order_example',
    'description': 'Controlled readable order fixture for authorized case work.',
    'primary_key': 'order_key',
    'source_model': 'fct_orders',
    'source_alias': 'orders',
    'columns': [
        {'name': 'order_key', 'expression': 'orders.order_key', 'data_type': 'string', 'description': 'Stable order fact key.'},
        {'name': 'customer_key', 'expression': 'orders.customer_key', 'data_type': 'string', 'description': 'Pseudonymous customer key.'},
        {'name': 'full_name', 'expression': 'mapped.full_name_value', 'data_type': 'string', 'description': 'Readable customer name for authorized case work.'}
    ],
    'helper_columns': [
        {'name': 'is_erased_customer', 'expression': 'orders.is_erased_customer'}
    ],
    'joins': [
        {'model': 'fa_pd_customer', 'alias': 'mapped', 'type': 'inner', true: 'orders.customer_key = mapped.customer_key'}
    ],
    'deletion': {
        'model_type': 'CASE_VIEW',
        'customer_key_column': 'customer_key',
        'erased_flag_column': 'is_erased_customer',
        'register_target': true
    }
} %}

{% set rendered_cases = [
    {'name': 'STAGING', 'sql': _layer_generator_render_model_sql(staging_spec, 'layer1'), 'fragments': ["ref('orders')", 'trim(source_rows.order_id)', "materialized='view'"]},
    {'name': 'QUARANTINE', 'sql': _layer_generator_render_model_sql(quarantine_spec, 'layer1'), 'fragments': ["model_type='QUARANTINE'", 'customer_key_expression=personal_data_key', "resolution_status != 'ACCEPTED'"]},
    {'name': 'CONTROL', 'sql': _layer_generator_render_model_sql(control_spec, 'layer1'), 'fragments': ["materialized='incremental'", "unique_key=\"decision_id\"", 'from candidate_decisions']},
    {'name': 'MAPPING', 'sql': _layer_generator_render_model_sql(mapping_spec, 'priva_map'), 'fragments': ["model_type='MAPPING'", "'order.id'", 'order_id_value']},
    {'name': 'KEYED', 'sql': _layer_generator_render_model_sql(keyed_spec, 'layer2'), 'fragments': ["materialized='ephemeral'", 'personal_data_key', "'customer.ssn'"]},
    {'name': 'RESOLUTION', 'sql': _layer_generator_render_model_sql(resolution_spec, 'layer2'), 'fragments': ['classified_orders as', 'deletion_mode', 'source_is_mode_annotated=true']},
    {'name': 'PUBLISHED', 'sql': _layer_generator_render_model_sql(published_spec, 'layer2'), 'fragments': ["resolution_status = 'ACCEPTED'", "ref('int_order_resolution')"]},
    {'name': 'LAYER2 CONTROL', 'sql': _layer_generator_render_model_sql(layer2_control_spec, 'layer2'), 'fragments': ["materialized='table'", "ref('int_customer_protected')"]},
    {'name': 'DIMENSION', 'sql': _layer_generator_render_model_sql(dimension_spec, 'layer3'), 'fragments': ['governed_rows as', "model_type='DIMENSION'", 'erased_subject_member as', "'ERASED_SUBJECT'", 'select * from governed_rows']},
    {'name': 'DATE_DIMENSION', 'sql': _layer_generator_render_model_sql(date_spec, 'layer3'), 'fragments': ['sequence(', 'date_dimension_start', 'iso_week_number']},
    {'name': 'FACT', 'sql': _layer_generator_render_model_sql(fact_spec, 'layer3'), 'fragments': ["model_type='FACT'", 'source_is_policy_applied=true', "primary_key=['order_key']"]},
    {'name': 'FRESH FACT', 'sql': _layer_generator_render_model_sql(fresh_fact_spec, 'layer3'), 'fragments': ["model_type='FACT'", "output_columns=['order_key', 'customer_key']", "erased_flag_column='is_erased_customer'"]},
    {'name': 'CASE_VIEW', 'sql': _layer_generator_render_model_sql(case_spec, 'layer3_case'), 'fragments': ["model_type='CASE_VIEW'", 'case_access_predicate()', 'orders.is_erased_customer as is_erased_customer']}
] %}

{% for rendered in rendered_cases %}
    {% for fragment in rendered['fragments'] %}
        {% if fragment not in rendered['sql'] %}
            {{ exceptions.raise_compiler_error(
                rendered['name'] ~ ' generator output is missing expected fragment: ' ~ fragment
            ) }}
        {% endif %}
    {% endfor %}
{% endfor %}

{% set mapping_yaml = _layer_generator_render_schema_yaml(mapping_spec, 'priva_map') %}
{% for fragment in [
    'databricks_tags:', 'personal_data_category', 'column_mask:',
    'mask_priva_map_value', 'using_columns: "order_key"'
] %}
    {% if fragment not in mapping_yaml %}
        {{ exceptions.raise_compiler_error(
            'MAPPING schema YAML is missing expected governance fragment: ' ~ fragment
        ) }}
    {% endif %}
{% endfor %}

{% set fresh_fact_yaml = _layer_generator_render_schema_yaml(fresh_fact_spec, 'layer3') %}
{% if '- name: is_erased_customer' not in fresh_fact_yaml %}
    {{ exceptions.raise_compiler_error('Fresh FACT schema YAML must document the generated erased flag') }}
{% endif %}

{% set fresh_fact_policy_sql = generate_customer_deletion_model(
    model_name='fct_fresh_order_example',
    model_type='FACT',
    source_relation='generated_rows',
    primary_key=['order_key'],
    output_columns=['order_key', 'customer_key'],
    customer_key_column='customer_key',
    special_replacement_columns=['customer_key'],
    erased_flag_column='is_erased_customer'
) %}
{% if 'as is_erased_customer' not in fresh_fact_policy_sql %}
    {{ exceptions.raise_compiler_error('Fresh FACT policy must append the erased flag') }}
{% endif %}

select 1 as generator_contract_failure where false
