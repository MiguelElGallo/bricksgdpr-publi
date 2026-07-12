{% macro _normalize_customer_deletion_generator_list(value, argument_name) -%}
    {% if value is string %}
        {% set normalized = [value] %}
    {% elif value is sequence %}
        {% set normalized = value %}
    {% else %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must be a string or list of strings') }}
    {% endif %}
    {% if normalized | length == 0 %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must not be empty') }}
    {% endif %}
    {% for item in normalized %}
        {% do _validate_deletion_policy_identifier(item, argument_name ~ '[' ~ loop.index0 ~ ']') %}
    {% endfor %}
    {{ return(normalized) }}
{%- endmacro %}

{% macro _validate_customer_deletion_model_type(model_type) -%}
    {% set normalized = model_type | upper %}
    {% set supported = [
        'FACT', 'DIMENSION', 'MAPPING', 'SERVICE', 'QUARANTINE', 'IDENTITY',
        'DEPENDENT', 'CASE_VIEW'
    ] %}
    {% if normalized not in supported %}
        {{ exceptions.raise_compiler_error(
            'model_type must be one of ' ~ supported | join(', ') ~ '; received: ' ~ model_type
        ) }}
    {% endif %}
    {{ return(normalized) }}
{%- endmacro %}

{% macro generate_customer_deletion_model(
    model_name,
    model_type,
    source_relation,
    primary_key,
    output_columns,
    customer_key_column='customer_key',
    customer_key_expression=none,
    special_replacement_columns=none,
    erased_flag_column='is_erased_customer',
    deletion_relation=none,
    source_is_mode_annotated=false,
    source_is_policy_applied=false,
    deletion_mode_column='deletion_mode',
    additional_predicate=none
) -%}
    {% do _validate_deletion_policy_identifier(model_name, 'model_name') %}
    {% set normalized_type = _validate_customer_deletion_model_type(model_type) %}
    {% set primary_keys = _normalize_customer_deletion_generator_list(primary_key, 'primary_key') %}
    {% do _validate_deletion_policy_columns(output_columns) %}
    {% for key_column in primary_keys %}
        {% if key_column not in output_columns %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': primary key is not present in output_columns: ' ~ key_column
            ) }}
        {% endif %}
    {% endfor %}
    {% if customer_key_column is not none %}
        {% do _validate_deletion_policy_identifier(customer_key_column, 'customer_key_column') %}
    {% endif %}
    {% if erased_flag_column is not none %}
        {% do _validate_deletion_policy_identifier(erased_flag_column, 'erased_flag_column') %}
    {% endif %}
    {% do _validate_deletion_policy_identifier(deletion_mode_column, 'deletion_mode_column') %}
    {% if source_is_mode_annotated and source_is_policy_applied %}
        {{ exceptions.raise_compiler_error(
            model_name ~ ': source_is_mode_annotated and source_is_policy_applied are mutually exclusive'
        ) }}
    {% endif %}
    {% if additional_predicate is not none and (
        additional_predicate is not string or additional_predicate | trim == ''
    ) %}
        {{ exceptions.raise_compiler_error('additional_predicate must be non-empty SQL') }}
    {% endif %}

    {% if source_is_policy_applied %}
        {% if normalized_type != 'FACT' %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': source_is_policy_applied is supported only for FACT'
            ) }}
        {% endif %}
        {% if additional_predicate is not none %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': source_is_policy_applied does not accept additional_predicate'
            ) }}
        {% endif %}
        {% set replacement_columns = _normalize_customer_deletion_generator_list(
            special_replacement_columns,
            'special_replacement_columns'
        ) %}
        {% if customer_key_column is none or customer_key_column not in replacement_columns %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': FACT must include customer_key_column in special_replacement_columns'
            ) }}
        {% endif %}
        {% if erased_flag_column is none or erased_flag_column not in output_columns %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': policy-applied FACT must project erased_flag_column'
            ) }}
        {% endif %}
        {% for column_name in replacement_columns %}
            {% if column_name not in output_columns %}
                {{ exceptions.raise_compiler_error(
                    model_name ~ ': replacement column is not in output_columns: ' ~ column_name
                ) }}
            {% endif %}
        {% endfor %}
        {% if deletion_relation is none %}
            {% set policy_ledger = ref('int_terminal_deleted_customer_keys') %}
        {% else %}
            {% set policy_ledger = deletion_relation %}
        {% endif %}
select
        {% for column_name in output_columns %}
    generated_rows.{{ column_name }}{% if not loop.last %},{% endif %}
        {% endfor %}
from {{ source_relation }} as generated_rows
left join {{ policy_ledger }} as policy_ledger
    on generated_rows.{{ customer_key_column }} = policy_ledger.customer_key
where policy_ledger.customer_key is null
    {% elif normalized_type == 'CASE_VIEW' %}
        {% if source_is_mode_annotated %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': CASE_VIEW does not accept source_is_mode_annotated'
            ) }}
        {% endif %}
        {% if special_replacement_columns is not none %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': CASE_VIEW does not accept special_replacement_columns'
            ) }}
        {% endif %}
        {% if erased_flag_column is none and customer_key_column is none %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': CASE_VIEW requires erased_flag_column or customer_key_column'
            ) }}
        {% endif %}
        {% if additional_predicate is none %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': CASE_VIEW requires additional_predicate for access control'
            ) }}
        {% endif %}
select
        {% for column_name in output_columns %}
    generated_rows.{{ column_name }}{% if not loop.last %},{% endif %}
        {% endfor %}
from {{ source_relation }} as generated_rows
where
        {% if additional_predicate is not none %}
    ({{ additional_predicate }})
    and
        {% endif %}
        {% if erased_flag_column is not none %}
    not generated_rows.{{ erased_flag_column }}
        {% else %}
    generated_rows.{{ customer_key_column }} != {{ erased_member_key() }}
        {% endif %}
    {% else %}
        {% if additional_predicate is not none %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': additional_predicate is supported only for CASE_VIEW'
            ) }}
        {% endif %}
        {% if special_replacement_columns is none %}
            {% set replacement_columns = [] %}
        {% else %}
            {% set replacement_columns = _normalize_customer_deletion_generator_list(
                special_replacement_columns,
                'special_replacement_columns'
            ) %}
        {% endif %}
        {% if normalized_type == 'FACT' %}
            {% if replacement_columns | length == 0 %}
                {{ exceptions.raise_compiler_error(
                    model_name ~ ': FACT requires special_replacement_columns'
                ) }}
            {% endif %}
            {% if erased_flag_column is none %}
                {{ exceptions.raise_compiler_error(model_name ~ ': FACT requires erased_flag_column') }}
            {% endif %}
            {% if customer_key_column is none or customer_key_column not in replacement_columns %}
                {{ exceptions.raise_compiler_error(
                    model_name ~ ': FACT must include customer_key_column in special_replacement_columns'
                ) }}
            {% endif %}
            {% for column_name in replacement_columns %}
                {% if column_name not in output_columns %}
                    {{ exceptions.raise_compiler_error(
                        model_name ~ ': replacement column is not in output_columns: ' ~ column_name
                    ) }}
                {% endif %}
            {% endfor %}
        {% elif replacement_columns | length > 0 %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': only FACT accepts special_replacement_columns'
            ) }}
        {% endif %}

        {% if source_is_mode_annotated %}
            {% set policy_source = source_relation %}
        {% else %}
            {% if customer_key_expression is none %}
                {% if customer_key_column is none %}
                    {{ exceptions.raise_compiler_error(
                        model_name ~ ': customer_key_column or customer_key_expression is required'
                    ) }}
                {% endif %}
                {% set resolved_customer_key_expression = 'source_rows.' ~ customer_key_column %}
            {% else %}
                {% if customer_key_expression is not string or customer_key_expression | trim == '' %}
                    {{ exceptions.raise_compiler_error(
                        model_name ~ ': customer_key_expression must be non-empty SQL'
                    ) }}
                {% endif %}
                {% set resolved_customer_key_expression = customer_key_expression %}
            {% endif %}
            {% set mode_annotated_sql %}
                {{ attach_customer_deletion_mode(
                    source_relation=source_relation,
                    customer_key_expression=resolved_customer_key_expression,
                    output_columns=output_columns,
                    deletion_relation=deletion_relation
                ) }}
            {% endset %}
            {% set policy_source = '(' ~ mode_annotated_sql ~ ')' %}
        {% endif %}

        {% if normalized_type == 'FACT' %}
            {% set replacements = {} %}
            {% for column_name in replacement_columns %}
                {% do replacements.update({column_name: erased_member_key()}) %}
            {% endfor %}
            {{ apply_customer_deletion_policy(
                source_relation=policy_source,
                output_columns=output_columns,
                special_behavior='REPLACE',
                special_replacements=replacements,
                erased_flag_column=erased_flag_column,
                deletion_mode_column=deletion_mode_column
            ) }}
        {% else %}
            {{ apply_customer_deletion_policy(
                source_relation=policy_source,
                output_columns=output_columns,
                special_behavior='DELETE',
                deletion_mode_column=deletion_mode_column
            ) }}
        {% endif %}
    {% endif %}
{%- endmacro %}

{% macro generate_customer_deletion_target_row(
    target_layer,
    model_name,
    model_type,
    target_kind=none
) -%}
    {% do _validate_deletion_policy_identifier(target_layer, 'target_layer') %}
    {% do _validate_deletion_policy_identifier(model_name, 'model_name') %}
    {% set normalized_type = _validate_customer_deletion_model_type(model_type) %}
    {% if target_kind is none %}
        {% set resolved_kind = 'VIEW' if normalized_type == 'CASE_VIEW' else 'TABLE' %}
    {% else %}
        {% set resolved_kind = target_kind | upper %}
    {% endif %}
    {% if resolved_kind not in ['TABLE', 'VIEW'] %}
        {{ exceptions.raise_compiler_error('target_kind must be TABLE or VIEW') }}
    {% endif %}
    {% if normalized_type == 'CASE_VIEW' and resolved_kind != 'VIEW' %}
        {{ exceptions.raise_compiler_error('CASE_VIEW target_kind must be VIEW') }}
    {% elif normalized_type != 'CASE_VIEW' and resolved_kind != 'TABLE' %}
        {{ exceptions.raise_compiler_error(normalized_type ~ ' target_kind must be TABLE') }}
    {% endif %}
    {% if normalized_type == 'FACT' %}
        {% set full_action = 'DELETE_CURRENT_ROWS' %}
        {% set special_action = 'REASSIGN_TO_ERASED_MEMBER' %}
    {% elif normalized_type == 'CASE_VIEW' %}
        {% set full_action = 'EXCLUDE_DELETED_ROWS' %}
        {% set special_action = 'EXCLUDE_ERASED_ROWS' %}
    {% else %}
        {% set full_action = 'DELETE_CURRENT_ROWS' %}
        {% set special_action = 'DELETE_CURRENT_ROWS' %}
    {% endif %}
('{{ target_layer }}', '{{ model_name }}', '{{ resolved_kind }}', '{{ full_action }}', '{{ special_action }}')
{%- endmacro %}

{% macro generate_customer_deletion_target_relations(targets) -%}
    {% if targets is string or targets is not sequence or targets | length == 0 %}
        {{ exceptions.raise_compiler_error('targets must be a non-empty list of mappings') }}
    {% endif %}
    {% set seen_models = [] %}
select *
from values
    {% for target in targets %}
        {% if target is not mapping %}
            {{ exceptions.raise_compiler_error('targets entries must be mappings') }}
        {% endif %}
        {% if target['model_name'] in seen_models %}
            {{ exceptions.raise_compiler_error(
                'duplicate customer deletion target: ' ~ target['model_name']
            ) }}
        {% endif %}
        {% do seen_models.append(target['model_name']) %}
    {{ generate_customer_deletion_target_row(
        target_layer=target['target_layer'],
        model_name=target['model_name'],
        model_type=target['model_type'],
        target_kind=target.get('target_kind')
    ) }}{% if not loop.last %},{% endif %}
    {% endfor %}
    as generated_targets(
        target_layer,
        target_relation,
        target_kind,
        full_deletion_action,
        special_deletion_action
    )
{%- endmacro %}

{% macro _render_customer_deletion_scaffold_list(values) -%}
[
    {%- for value in values -%}
'{{ value }}'{% if not loop.last %}, {% endif %}
    {%- endfor -%}
]
{%- endmacro %}

{% macro generate_customer_deletion_scaffold(
    model_name,
    model_type,
    target_layer,
    source_model,
    primary_key,
    output_columns,
    customer_key_column='customer_key',
    customer_key_expression=none,
    customer_key_domain=none,
    customer_key_kind='text',
    special_replacement_columns=none,
    erased_flag_column=none,
    source_is_policy_applied=false,
    target_kind=none
) -%}
    {% do _validate_deletion_policy_identifier(source_model, 'source_model') %}
    {% set normalized_type = _validate_customer_deletion_model_type(model_type) %}
    {% set primary_keys = _normalize_customer_deletion_generator_list(primary_key, 'primary_key') %}
    {% do _validate_deletion_policy_columns(output_columns) %}
    {% for key_column in primary_keys %}
        {% if key_column not in output_columns %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': primary key is not present in output_columns: ' ~ key_column
            ) }}
        {% endif %}
    {% endfor %}
    {% do _validate_deletion_policy_identifier(customer_key_column, 'customer_key_column') %}
    {% if normalized_type == 'CASE_VIEW' and customer_key_column not in output_columns %}
        {{ exceptions.raise_compiler_error(
            model_name ~ ': CASE_VIEW scaffold requires customer_key_column in output_columns '
            ~ 'so the generated contract can verify erased-member exclusion'
        ) }}
    {% endif %}
    {% if customer_key_expression is not none and customer_key_domain is not none %}
        {{ exceptions.raise_compiler_error(
            'scaffold accepts customer_key_expression or customer_key_domain, not both'
        ) }}
    {% endif %}
    {% if customer_key_domain is not none %}
        {% if customer_key_domain is not string or customer_key_domain | trim == '' %}
            {{ exceptions.raise_compiler_error('customer_key_domain must be non-empty') }}
        {% endif %}
        {% set customer_key_kind = _validate_personal_data_kind(
            customer_key_kind, 'customer_key_kind'
        ) %}
        {% set model_customer_key_expression = "personal_data_key('source_rows."
            ~ customer_key_column ~ "', '" ~ customer_key_domain | replace("'", "''")
            ~ "', '" ~ customer_key_kind | replace("'", "''") ~ "')" %}
        {% set contract_customer_key_expression = none %}
    {% elif customer_key_expression is not none %}
        {% if customer_key_expression is not string or customer_key_expression | trim == '' %}
            {{ exceptions.raise_compiler_error('customer_key_expression must be non-empty SQL') }}
        {% endif %}
        {% if 'source_rows.' not in customer_key_expression %}
            {{ exceptions.raise_compiler_error(
                'scaffold customer_key_expression must reference source_rows'
            ) }}
        {% endif %}
        {% set contract_customer_key_expression = customer_key_expression
            | replace('source_rows.', 'generated_model.') %}
        {% set model_customer_key_expression = customer_key_expression | tojson %}
    {% else %}
        {% set contract_customer_key_expression = none %}
        {% set model_customer_key_expression = none %}
    {% endif %}
    {% if special_replacement_columns is none %}
        {% set replacement_columns = [] %}
    {% else %}
        {% set replacement_columns = _normalize_customer_deletion_generator_list(
            special_replacement_columns,
            'special_replacement_columns'
        ) %}
    {% endif %}
    {% for column_name in replacement_columns %}
        {% if column_name not in output_columns %}
            {{ exceptions.raise_compiler_error(
                model_name ~ ': replacement column is not in output_columns: ' ~ column_name
            ) }}
        {% endif %}
    {% endfor %}
    {% set resolved_erased_flag = erased_flag_column %}
    {% if normalized_type == 'FACT' and resolved_erased_flag is none %}
        {% set resolved_erased_flag = 'is_erased_customer' %}
    {% endif %}
    {% if normalized_type == 'FACT' and replacement_columns | length == 0 %}
        {{ exceptions.raise_compiler_error(model_name ~ ': FACT requires special_replacement_columns') }}
    {% endif %}
    {% if normalized_type == 'FACT' and customer_key_column not in replacement_columns %}
        {{ exceptions.raise_compiler_error(
            model_name ~ ': FACT must include customer_key_column in special_replacement_columns'
        ) }}
    {% endif %}
    {% if source_is_policy_applied and normalized_type != 'FACT' %}
        {{ exceptions.raise_compiler_error(
            model_name ~ ': source_is_policy_applied is supported only for FACT'
        ) }}
    {% endif %}
    {% if source_is_policy_applied and resolved_erased_flag not in output_columns %}
        {{ exceptions.raise_compiler_error(
            model_name ~ ': policy-applied FACT must include erased_flag_column in output_columns'
        ) }}
    {% endif %}
    {% set target_row = generate_customer_deletion_target_row(
        target_layer=target_layer,
        model_name=model_name,
        model_type=normalized_type,
        target_kind=target_kind
    ) %}
    {% set registry_entry %}
{'target_layer': '{{ target_layer }}', 'model_name': '{{ model_name }}', 'model_type': '{{ normalized_type }}'{% if target_kind is not none %}, 'target_kind': '{{ target_kind | upper }}'{% endif %}}
    {% endset %}
    {% set model_sql %}
{{ '{{' }} generate_customer_deletion_model(
    model_name='{{ model_name }}',
    model_type='{{ normalized_type }}',
    source_relation=ref('{{ source_model }}'),
    primary_key={{ _render_customer_deletion_scaffold_list(primary_keys) }},
    output_columns={{ _render_customer_deletion_scaffold_list(output_columns) }},
    customer_key_column='{{ customer_key_column }}'{% if model_customer_key_expression is not none %},
    customer_key_expression={{ model_customer_key_expression }}{% endif %}{% if replacement_columns | length > 0 %},
    special_replacement_columns={{ _render_customer_deletion_scaffold_list(replacement_columns) }},
    erased_flag_column='{{ resolved_erased_flag }}'{% if source_is_policy_applied %},
    source_is_policy_applied=true{% endif %}{% elif normalized_type == 'CASE_VIEW' %},
    erased_flag_column={% if resolved_erased_flag is none %}none{% else %}'{{ resolved_erased_flag }}'{% endif %},
    additional_predicate=case_access_predicate(){% endif %}
) {{ '}}' }}
    {% endset %}
    {% set contract_key_columns = replacement_columns
        if normalized_type == 'FACT' else [customer_key_column] %}
    {% set yaml_lines = [] %}
    {% do yaml_lines.append('- name: ' ~ model_name) %}
    {% do yaml_lines.append('  description: >') %}
    {% do yaml_lines.append(
        '    One governed row per ' ~ primary_keys | join(' + ')
        ~ '. Customer deletion behavior is generated'
    ) %}
    {% do yaml_lines.append(
        '    from the ' ~ normalized_type
        ~ ' contract so FULL and SPECIAL modes cannot diverge by hand.'
    ) %}
    {% do yaml_lines.append('  data_tests:') %}
    {% do yaml_lines.append('    - customer_deletion_generated_contract:') %}
    {% do yaml_lines.append('        arguments:') %}
    {% do yaml_lines.append('          model_type: ' ~ normalized_type) %}
    {% do yaml_lines.append('          primary_key: ' ~ primary_keys) %}
    {% do yaml_lines.append('          customer_key_columns: ' ~ contract_key_columns) %}
    {% do yaml_lines.append('          customer_key_column: ' ~ customer_key_column) %}
    {% if customer_key_domain is not none %}
        {% do yaml_lines.append('          customer_key_domain: ' ~ customer_key_domain) %}
        {% do yaml_lines.append('          customer_key_kind: ' ~ customer_key_kind) %}
    {% elif contract_customer_key_expression is not none %}
        {% do yaml_lines.append('          customer_key_expression: >') %}
        {% do yaml_lines.append('            ' ~ contract_customer_key_expression) %}
    {% endif %}
    {% if normalized_type == 'FACT' %}
        {% do yaml_lines.append('          erased_flag_column: ' ~ resolved_erased_flag) %}
    {% endif %}
    {% do yaml_lines.append('  columns:') %}
    {% for key_column in primary_keys %}
        {% do yaml_lines.append('    - name: ' ~ key_column) %}
        {% set key_tests = '[not_null, unique]' if primary_keys | length == 1 else '[not_null]' %}
        {% do yaml_lines.append('      data_tests: ' ~ key_tests) %}
    {% endfor %}
    {% if normalized_type == 'FACT' %}
        {% do yaml_lines.append('    - name: ' ~ resolved_erased_flag) %}
        {% do yaml_lines.append(
            '      description: True only when SPECIAL retains the fact under the erased member.'
        ) %}
        {% do yaml_lines.append('      data_tests: [not_null]') %}
    {% endif %}
    {% set schema_yaml = yaml_lines | join('\n') %}
    {% do log('\nMODEL SQL\n' ~ model_sql | trim, info=true) %}
    {% do log('\nTARGET REGISTRY ENTRY\n' ~ registry_entry | trim, info=true) %}
    {% do log('\nDERIVED TARGET ROW\n' ~ target_row | trim, info=true) %}
    {% do log('\nSCHEMA YAML\n' ~ schema_yaml | trim, info=true) %}
    {{ return('Generated scaffold for ' ~ model_name) }}
{%- endmacro %}

{% test customer_deletion_generated_contract(
    model,
    model_type,
    primary_key,
    customer_key_columns,
    customer_key_column='customer_key',
    customer_key_expression=none,
    customer_key_domain=none,
    customer_key_kind='text',
    erased_flag_column=none
) -%}
    {% set normalized_type = _validate_customer_deletion_model_type(model_type) %}
    {% set primary_keys = _normalize_customer_deletion_generator_list(primary_key, 'primary_key') %}
    {% set key_columns = _normalize_customer_deletion_generator_list(
        customer_key_columns,
        'customer_key_columns'
    ) %}
    {% do _validate_deletion_policy_identifier(customer_key_column, 'customer_key_column') %}
    {% if customer_key_expression is not none and customer_key_expression | string | trim == '' %}
        {{ exceptions.raise_compiler_error('customer_key_expression must be non-empty SQL') }}
    {% endif %}
    {% if customer_key_expression is not none and customer_key_domain is not none %}
        {{ exceptions.raise_compiler_error(
            'contract accepts customer_key_expression or customer_key_domain, not both'
        ) }}
    {% endif %}
    {% if normalized_type not in ['FACT', 'CASE_VIEW'] and key_columns | length != 1 %}
        {{ exceptions.raise_compiler_error(
            'delete-style generated contracts require exactly one customer key column'
        ) }}
    {% endif %}
with contract_failures as (
    select 'NULL_PRIMARY_KEY' as failure_reason
    from {{ model }}
    where
        {% for key_column in primary_keys %}
        {{ key_column }} is null{% if not loop.last %} or{% endif %}
        {% endfor %}

    union all

    select 'DUPLICATE_PRIMARY_KEY' as failure_reason
    from {{ model }}
    group by
        {% for key_column in primary_keys %}
        {{ key_column }}{% if not loop.last %},{% endif %}
        {% endfor %}
    having count(*) > 1

    {% if normalized_type == 'FACT' %}
        {% if erased_flag_column is none %}
            {{ exceptions.raise_compiler_error('FACT contract requires erased_flag_column') }}
        {% endif %}

    union all

    select 'INVALID_ERASED_MEMBER' as failure_reason
    from {{ model }}
    where
        {{ erased_flag_column }} is null
        or (
            {{ erased_flag_column }}
            and (
                {% for key_column in key_columns %}
                not ({{ key_column }} <=> {{ erased_member_key() }}){% if not loop.last %} or{% endif %}
                {% endfor %}
            )
        )
        or (
            not {{ erased_flag_column }}
            and (
                {% for key_column in key_columns %}
                {{ key_column }} <=> {{ erased_member_key() }}{% if not loop.last %} or{% endif %}
                {% endfor %}
            )
        )

    union all

    select 'DELETED_CUSTOMER_VISIBLE' as failure_reason
    from {{ model }} as generated_model
    inner join {{ ref('int_terminal_deleted_customer_keys') }} as deleted
        on generated_model.{{ customer_key_column }} = deleted.customer_key
    {% elif normalized_type == 'CASE_VIEW' %}

    union all

    select 'ERASED_MEMBER_VISIBLE_IN_CASE_VIEW' as failure_reason
    from {{ model }}
    where
        {% for key_column in key_columns %}
        {{ key_column }} <=> {{ erased_member_key() }}{% if not loop.last %} or{% endif %}
        {% endfor %}
    {% else %}

    union all

    select 'DELETED_CUSTOMER_VISIBLE' as failure_reason
    from {{ model }} as generated_model
    inner join {{ ref('int_terminal_deleted_customer_keys') }} as deleted
        on
        {% if customer_key_domain is not none %}
        {{ personal_data_key(
            'generated_model.' ~ customer_key_column,
            customer_key_domain,
            customer_key_kind
        ) }} = deleted.customer_key
        {% elif customer_key_expression is not none %}
        {{ customer_key_expression | string }} = deleted.customer_key
        {% else %}
        generated_model.{{ customer_key_column }} = deleted.customer_key
        {% endif %}
    {% endif %}
)

select * from contract_failures
{%- endtest %}
