{% macro _layer_generator_require_string(value, argument_name) -%}
    {% if value is not string or value | trim == '' %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must be a non-empty string') }}
    {% endif %}
    {{ return(value | trim) }}
{%- endmacro %}

{% macro _layer_generator_require_sequence(value, argument_name, allow_empty=false) -%}
    {% if value is string or value is not sequence %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must be a list') }}
    {% endif %}
    {% if not allow_empty and value | length == 0 %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must not be empty') }}
    {% endif %}
    {{ return(value) }}
{%- endmacro %}

{% macro _layer_generator_validate_keys(value, allowed_keys, argument_name) -%}
    {% if value is not mapping %}
        {{ exceptions.raise_compiler_error(argument_name ~ ' must be a mapping') }}
    {% endif %}
    {% for key in value.keys() %}
        {% if key not in allowed_keys %}
            {{ exceptions.raise_compiler_error(argument_name ~ ' contains unsupported key: ' ~ key) }}
        {% endif %}
    {% endfor %}
{%- endmacro %}

{% macro _layer_generator_normalize_columns(columns) -%}
    {% do _layer_generator_require_sequence(columns, 'columns') %}
    {% set names = [] %}
    {% set allowed = [
        'name', 'expression', 'key', 'data_type', 'description', 'tests',
        'databricks_tags', 'column_mask'
    ] %}
    {% for column in columns %}
        {% do _layer_generator_validate_keys(column, allowed, 'columns[' ~ loop.index0 ~ ']') %}
        {% if 'name' not in column %}
            {{ exceptions.raise_compiler_error('columns[' ~ loop.index0 ~ '] requires name') }}
        {% endif %}
        {% do _validate_deletion_policy_identifier(column['name'], 'columns[' ~ loop.index0 ~ '].name') %}
        {% if column['name'] in names %}
            {{ exceptions.raise_compiler_error('columns contains duplicate name: ' ~ column['name']) }}
        {% endif %}
        {% do names.append(column['name']) %}
        {% do _layer_generator_require_string(
            column.get('data_type'), 'columns[' ~ loop.index0 ~ '].data_type'
        ) %}
        {% do _layer_generator_require_string(
            column.get('description'), 'columns[' ~ loop.index0 ~ '].description'
        ) %}
        {% if column.get('expression') is not none and column.get('key') is not none %}
            {{ exceptions.raise_compiler_error(
                'columns[' ~ loop.index0 ~ '] accepts expression or key, not both'
            ) }}
        {% endif %}
        {% if column.get('expression') is not none %}
            {% do _layer_generator_require_string(
                column.get('expression'), 'columns[' ~ loop.index0 ~ '].expression'
            ) %}
        {% endif %}
        {% if column.get('key') is not none %}
            {% set key = column.get('key') %}
            {% do _layer_generator_validate_keys(
                key, ['expression', 'domain', 'kind'], 'columns[' ~ loop.index0 ~ '].key'
            ) %}
            {% do _layer_generator_require_string(
                key.get('expression'), 'columns[' ~ loop.index0 ~ '].key.expression'
            ) %}
            {% do _layer_generator_require_string(
                key.get('domain'), 'columns[' ~ loop.index0 ~ '].key.domain'
            ) %}
            {% if key.get('kind') is not none %}
                {% do _validate_personal_data_kind(
                    key.get('kind'), 'columns[' ~ loop.index0 ~ '].key.kind'
                ) %}
            {% endif %}
        {% endif %}
        {% if column.get('tests') is not none %}
            {% do _layer_generator_require_sequence(
                column.get('tests'), 'columns[' ~ loop.index0 ~ '].tests', allow_empty=true
            ) %}
            {% for test_name in column.get('tests') %}
                {% do _layer_generator_require_string(
                    test_name, 'columns[' ~ loop.index0 ~ '].tests[' ~ loop.index0 ~ ']'
                ) %}
            {% endfor %}
        {% endif %}
        {% if column.get('databricks_tags') is not none %}
            {% if column.get('databricks_tags') is not mapping %}
                {{ exceptions.raise_compiler_error(
                    'columns[' ~ loop.index0 ~ '].databricks_tags must be a mapping'
                ) }}
            {% endif %}
            {% for tag_name, tag_value in column.get('databricks_tags').items() %}
                {% do _layer_generator_require_string(
                    tag_name, 'columns[' ~ loop.index0 ~ '].databricks_tags key'
                ) %}
                {% do _layer_generator_require_string(
                    tag_value,
                    'columns[' ~ loop.index0 ~ '].databricks_tags.' ~ tag_name
                ) %}
            {% endfor %}
        {% endif %}
        {% if column.get('column_mask') is not none %}
            {% set column_mask = column.get('column_mask') %}
            {% do _layer_generator_validate_keys(
                column_mask, ['function', 'using_columns'],
                'columns[' ~ loop.index0 ~ '].column_mask'
            ) %}
            {% do _layer_generator_require_string(
                column_mask.get('function'),
                'columns[' ~ loop.index0 ~ '].column_mask.function'
            ) %}
            {% if column_mask.get('using_columns') is not none %}
                {% do _layer_generator_require_string(
                    column_mask.get('using_columns'),
                    'columns[' ~ loop.index0 ~ '].column_mask.using_columns'
                ) %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return(names) }}
{%- endmacro %}

{% macro _layer_generator_normalize_helper_columns(columns) -%}
    {% if columns is none %}{{ return([]) }}{% endif %}
    {% do _layer_generator_require_sequence(columns, 'helper_columns', allow_empty=true) %}
    {% set names = [] %}
    {% for column in columns %}
        {% do _layer_generator_validate_keys(
            column, ['name', 'expression', 'key'], 'helper_columns[' ~ loop.index0 ~ ']'
        ) %}
        {% do _validate_deletion_policy_identifier(
            column.get('name'), 'helper_columns[' ~ loop.index0 ~ '].name'
        ) %}
        {% if column.get('name') in names %}
            {{ exceptions.raise_compiler_error(
                'helper_columns contains duplicate name: ' ~ column.get('name')
            ) }}
        {% endif %}
        {% do names.append(column.get('name')) %}
        {% if column.get('expression') is not none and column.get('key') is not none %}
            {{ exceptions.raise_compiler_error(
                'helper_columns[' ~ loop.index0 ~ '] accepts expression or key, not both'
            ) }}
        {% endif %}
        {% if column.get('expression') is not none %}
            {% do _layer_generator_require_string(
                column.get('expression'), 'helper_columns[' ~ loop.index0 ~ '].expression'
            ) %}
        {% endif %}
        {% if column.get('key') is not none %}
            {% do _layer_generator_validate_keys(
                column.get('key'), ['expression', 'domain', 'kind'],
                'helper_columns[' ~ loop.index0 ~ '].key'
            ) %}
            {% do _layer_generator_require_string(
                column.get('key').get('expression'),
                'helper_columns[' ~ loop.index0 ~ '].key.expression'
            ) %}
            {% do _layer_generator_require_string(
                column.get('key').get('domain'),
                'helper_columns[' ~ loop.index0 ~ '].key.domain'
            ) %}
            {% if column.get('key').get('kind') is not none %}
                {% do _validate_personal_data_kind(
                    column.get('key').get('kind'),
                    'helper_columns[' ~ loop.index0 ~ '].key.kind'
                ) %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return(columns) }}
{%- endmacro %}

{% macro _layer_generator_normalize_spec(spec, forced_layer=none) -%}
    {% set allowed = [
        'layer', 'model_kind', 'model_name', 'description', 'primary_key', 'columns',
        'helper_columns',
        'source_model', 'source_cte', 'source_alias', 'ctes', 'joins', 'where', 'tags', 'materialized',
        'incremental', 'deletion', 'erased_member', 'start_var', 'end_var',
        'databricks_tags'
    ] %}
    {% do _layer_generator_validate_keys(spec, allowed, 'spec') %}
    {% if forced_layer is none %}
        {% set layer = _layer_generator_require_string(spec.get('layer'), 'spec.layer') | lower %}
    {% else %}
        {% set layer = forced_layer | lower %}
        {% if spec.get('layer') is not none and spec.get('layer') | lower != layer %}
            {{ exceptions.raise_compiler_error(
                'spec.layer does not match the selected generator: ' ~ spec.get('layer')
            ) }}
        {% endif %}
    {% endif %}
    {% set kind = _layer_generator_require_string(spec.get('model_kind'), 'spec.model_kind') | upper %}
    {% set allowed_kinds = {
        'layer1': ['STAGING', 'QUARANTINE', 'CONTROL'],
        'priva_map': ['MAPPING'],
        'layer2': ['KEYED', 'RESOLUTION', 'PUBLISHED', 'CONTROL'],
        'layer3': ['DIMENSION', 'DATE_DIMENSION', 'FACT'],
        'layer3_case': ['CASE_VIEW']
    } %}
    {% if layer not in allowed_kinds %}
        {{ exceptions.raise_compiler_error('spec.layer must be one of ' ~ allowed_kinds.keys() | join(', ')) }}
    {% endif %}
    {% if kind not in allowed_kinds[layer] %}
        {{ exceptions.raise_compiler_error(
            layer ~ ' model_kind must be one of ' ~ allowed_kinds[layer] | join(', ')
        ) }}
    {% endif %}
    {% set model_name = _layer_generator_require_string(spec.get('model_name'), 'spec.model_name') %}
    {% do _validate_deletion_policy_identifier(model_name, 'spec.model_name') %}
    {% do _layer_generator_require_string(spec.get('description'), 'spec.description') %}

    {% if kind == 'DATE_DIMENSION' %}
        {% for unsupported_key in [
            'primary_key', 'columns', 'helper_columns', 'source_model', 'source_cte',
            'source_alias', 'ctes', 'joins', 'where', 'deletion', 'erased_member'
        ] %}
            {% if spec.get(unsupported_key) is not none %}
                {{ exceptions.raise_compiler_error(
                    'DATE_DIMENSION does not accept spec.' ~ unsupported_key
                ) }}
            {% endif %}
        {% endfor %}
        {% for variable_key in ['start_var', 'end_var'] %}
            {% if spec.get(variable_key) is not none %}
                {% do _validate_deletion_policy_identifier(
                    spec.get(variable_key), 'spec.' ~ variable_key
                ) %}
            {% endif %}
        {% endfor %}
        {% set columns = [
            {'name': 'date_key', 'data_type': 'int', 'description': 'Integer date key in YYYYMMDD form.', 'tests': ['not_null', 'unique']},
            {'name': 'date_day', 'data_type': 'date', 'description': 'Calendar date.', 'tests': ['not_null', 'unique']},
            {'name': 'calendar_year', 'data_type': 'int', 'description': 'Four-digit calendar year.', 'tests': ['not_null']},
            {'name': 'calendar_quarter', 'data_type': 'int', 'description': 'Calendar quarter number.', 'tests': ['not_null']},
            {'name': 'month_number', 'data_type': 'int', 'description': 'Calendar month number.', 'tests': ['not_null']},
            {'name': 'month_name', 'data_type': 'string', 'description': 'Full calendar month name.', 'tests': ['not_null']},
            {'name': 'day_of_month', 'data_type': 'int', 'description': 'Day number within the month.', 'tests': ['not_null']},
            {'name': 'day_of_week', 'data_type': 'int', 'description': 'Databricks day-of-week number.', 'tests': ['not_null']},
            {'name': 'day_name', 'data_type': 'string', 'description': 'Full weekday name.', 'tests': ['not_null']},
            {'name': 'iso_week_number', 'data_type': 'int', 'description': 'ISO-style week number.', 'tests': ['not_null']},
            {'name': 'is_weekend', 'data_type': 'boolean', 'description': 'True for Saturday or Sunday.', 'tests': ['not_null']}
        ] %}
        {% set primary_keys = ['date_key'] %}
    {% else %}
        {% set columns = spec.get('columns') %}
        {% set column_names = _layer_generator_normalize_columns(columns) %}
        {% for column in columns %}
            {% if column.get('column_mask') is not none and kind != 'MAPPING' %}
                {{ exceptions.raise_compiler_error(
                    'column_mask is supported only for MAPPING scaffolds'
                ) }}
            {% endif %}
        {% endfor %}
        {% set materialized = _layer_generator_materialization(spec, kind) %}
        {% for column in columns %}
            {% if (column.get('column_mask') is not none
                or column.get('databricks_tags') is not none)
                and materialized not in ['table', 'incremental'] %}
                {{ exceptions.raise_compiler_error(
                    'column-level Databricks tags and masks require table or incremental materialization'
                ) }}
            {% endif %}
        {% endfor %}
        {% set primary_keys = _normalize_customer_deletion_generator_list(
            spec.get('primary_key'), 'spec.primary_key'
        ) %}
        {% for key_column in primary_keys %}
            {% if key_column not in column_names %}
                {{ exceptions.raise_compiler_error(
                    'spec.primary_key is not present in columns: ' ~ key_column
                ) }}
            {% endif %}
        {% endfor %}
        {% if (spec.get('source_model') is none) == (spec.get('source_cte') is none) %}
            {{ exceptions.raise_compiler_error(
                'spec requires exactly one of source_model or source_cte'
            ) }}
        {% endif %}
        {% if spec.get('source_model') is not none %}
            {% do _layer_generator_require_string(spec.get('source_model'), 'spec.source_model') %}
            {% do _validate_deletion_policy_identifier(spec.get('source_model'), 'spec.source_model') %}
        {% else %}
            {% do _validate_deletion_policy_identifier(spec.get('source_cte'), 'spec.source_cte') %}
        {% endif %}
    {% endif %}

    {% if spec.get('source_alias') is not none %}
        {% do _validate_deletion_policy_identifier(spec.get('source_alias'), 'spec.source_alias') %}
    {% endif %}
    {% set helper_columns = _layer_generator_normalize_helper_columns(spec.get('helper_columns')) %}
    {% if helper_columns | length > 0 and spec.get('deletion') is none %}
        {{ exceptions.raise_compiler_error('helper_columns requires spec.deletion') }}
    {% endif %}
    {% set visible_names = [] %}
    {% for column in columns %}{% do visible_names.append(column['name']) %}{% endfor %}
    {% for column in helper_columns %}
        {% if column['name'] in visible_names %}
            {{ exceptions.raise_compiler_error(
                'helper column duplicates visible column: ' ~ column['name']
            ) }}
        {% endif %}
    {% endfor %}
    {% set reserved_names = ['generated_rows', 'governed_rows', 'erased_subject_member'] %}
    {% set cte_names = [] %}
    {% if spec.get('ctes') is not none %}
        {% do _layer_generator_require_sequence(spec.get('ctes'), 'spec.ctes', allow_empty=true) %}
        {% for cte in spec.get('ctes') %}
            {% do _layer_generator_validate_keys(cte, ['name', 'sql'], 'spec.ctes[' ~ loop.index0 ~ ']') %}
            {% do _validate_deletion_policy_identifier(cte.get('name'), 'spec.ctes[' ~ loop.index0 ~ '].name') %}
            {% do _layer_generator_require_string(cte.get('sql'), 'spec.ctes[' ~ loop.index0 ~ '].sql') %}
            {% if cte.get('name') in cte_names %}
                {{ exceptions.raise_compiler_error('spec.ctes contains duplicate name: ' ~ cte.get('name')) }}
            {% endif %}
            {% if cte.get('name') in reserved_names %}
                {{ exceptions.raise_compiler_error('spec.ctes uses reserved name: ' ~ cte.get('name')) }}
            {% endif %}
            {% do cte_names.append(cte.get('name')) %}
        {% endfor %}
    {% endif %}
    {% if spec.get('source_cte') is not none and spec.get('source_cte') not in cte_names %}
        {{ exceptions.raise_compiler_error(
            'spec.source_cte must name an entry in spec.ctes: ' ~ spec.get('source_cte')
        ) }}
    {% endif %}
    {% set relation_aliases = [spec.get('source_alias', 'source_rows')] %}
    {% if relation_aliases[0] in reserved_names %}
        {{ exceptions.raise_compiler_error('spec.source_alias uses reserved name: ' ~ relation_aliases[0]) }}
    {% endif %}
    {% if spec.get('joins') is not none %}
        {% do _layer_generator_require_sequence(spec.get('joins'), 'spec.joins', allow_empty=true) %}
        {% for join in spec.get('joins') %}
            {% do _layer_generator_validate_keys(
                join, ['model', 'cte', 'alias', 'type', 'on', true], 'spec.joins[' ~ loop.index0 ~ ']'
            ) %}
            {% if join.get('on') is not none and join.get(true) is not none %}
                {{ exceptions.raise_compiler_error(
                    'spec.joins[' ~ loop.index0 ~ '] cannot contain both "on" and YAML boolean true keys'
                ) }}
            {% endif %}
            {% if (join.get('model') is none) == (join.get('cte') is none) %}
                {{ exceptions.raise_compiler_error(
                    'spec.joins[' ~ loop.index0 ~ '] requires exactly one of model or cte'
                ) }}
            {% endif %}
            {% if join.get('model') is not none %}
                {% do _validate_deletion_policy_identifier(
                    join.get('model'), 'spec.joins[' ~ loop.index0 ~ '].model'
                ) %}
            {% else %}
                {% do _validate_deletion_policy_identifier(
                    join.get('cte'), 'spec.joins[' ~ loop.index0 ~ '].cte'
                ) %}
                {% if join.get('cte') not in cte_names %}
                    {{ exceptions.raise_compiler_error(
                        'spec.joins[' ~ loop.index0 ~ '].cte must name an entry in spec.ctes: '
                        ~ join.get('cte')
                    ) }}
                {% endif %}
            {% endif %}
            {% do _validate_deletion_policy_identifier(join.get('alias'), 'spec.joins[' ~ loop.index0 ~ '].alias') %}
            {% if join.get('alias') in relation_aliases %}
                {{ exceptions.raise_compiler_error('duplicate relation alias: ' ~ join.get('alias')) }}
            {% endif %}
            {% if join.get('alias') in reserved_names %}
                {{ exceptions.raise_compiler_error('join alias uses reserved name: ' ~ join.get('alias')) }}
            {% endif %}
            {% do relation_aliases.append(join.get('alias')) %}
            {% set join_type = join.get('type', 'inner') | lower %}
            {% if join_type not in ['inner', 'left', 'cross'] %}
                {{ exceptions.raise_compiler_error('join type must be inner, left, or cross') }}
            {% endif %}
            {% if join_type != 'cross' %}
                {% do _layer_generator_require_string(
                    join.get('on', join.get(true)), 'spec.joins[' ~ loop.index0 ~ '].on'
                ) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% if spec.get('where') is not none %}
        {% do _layer_generator_require_sequence(spec.get('where'), 'spec.where', allow_empty=true) %}
        {% for predicate in spec.get('where') %}
            {% do _layer_generator_require_string(predicate, 'spec.where[' ~ loop.index0 ~ ']') %}
        {% endfor %}
    {% endif %}
    {% if spec.get('tags') is not none %}
        {% do _layer_generator_require_sequence(spec.get('tags'), 'spec.tags', allow_empty=true) %}
        {% for tag in spec.get('tags') %}
            {% do _layer_generator_require_string(tag, 'spec.tags[' ~ loop.index0 ~ ']') %}
        {% endfor %}
    {% endif %}
    {% if spec.get('databricks_tags') is not none %}
        {% do _layer_generator_validate_keys(
            spec.get('databricks_tags'), spec.get('databricks_tags').keys(), 'spec.databricks_tags'
        ) %}
        {% for key, value in spec.get('databricks_tags').items() %}
            {% do _layer_generator_require_string(key, 'spec.databricks_tags key') %}
            {% do _layer_generator_require_string(value, 'spec.databricks_tags.' ~ key) %}
        {% endfor %}
    {% endif %}
    {% if spec.get('incremental') is not none %}
        {% set incremental = spec.get('incremental') %}
        {% do _layer_generator_validate_keys(
            incremental, ['unique_key', 'strategy', 'on_schema_change'], 'spec.incremental'
        ) %}
        {% if incremental.get('unique_key') is none %}
            {{ exceptions.raise_compiler_error('spec.incremental requires unique_key') }}
        {% endif %}
        {% set incremental_keys = _normalize_customer_deletion_generator_list(
            incremental.get('unique_key'), 'spec.incremental.unique_key'
        ) %}
        {% for incremental_key in incremental_keys %}
            {% if incremental_key not in visible_names %}
                {{ exceptions.raise_compiler_error(
                    'spec.incremental.unique_key is not present in columns: ' ~ incremental_key
                ) }}
            {% endif %}
        {% endfor %}
        {% do _layer_generator_require_string(
            incremental.get('strategy', 'merge'), 'spec.incremental.strategy'
        ) %}
        {% do _layer_generator_require_string(
            incremental.get('on_schema_change', 'fail'), 'spec.incremental.on_schema_change'
        ) %}
    {% endif %}
    {% if spec.get('erased_member') is not none %}
        {% if kind != 'DIMENSION' %}
            {{ exceptions.raise_compiler_error('spec.erased_member is supported only for DIMENSION') }}
        {% endif %}
        {% do _layer_generator_validate_keys(
            spec.get('erased_member'), visible_names, 'spec.erased_member'
        ) %}
        {% for column_name, expression in spec.get('erased_member').items() %}
            {% do _layer_generator_require_string(
                expression, 'spec.erased_member.' ~ column_name
            ) %}
        {% endfor %}
    {% endif %}
    {{ return({
        'layer': layer,
        'kind': kind,
        'columns': columns,
        'helper_columns': helper_columns,
        'primary_keys': primary_keys
    }) }}
{%- endmacro %}

{% macro _layer_generator_materialization(spec, kind) -%}
    {% set defaults = {
        'STAGING': 'view', 'QUARANTINE': 'table', 'CONTROL': 'table', 'MAPPING': 'table',
        'KEYED': 'ephemeral', 'RESOLUTION': 'ephemeral', 'PUBLISHED': 'table',
        'DIMENSION': 'table', 'DATE_DIMENSION': 'table', 'FACT': 'table', 'CASE_VIEW': 'view'
    } %}
    {% set materialized = spec.get('materialized', defaults[kind]) | lower %}
    {% if materialized not in ['view', 'table', 'incremental', 'ephemeral'] %}
        {{ exceptions.raise_compiler_error('spec.materialized must be view, table, incremental, or ephemeral') }}
    {% endif %}
    {% if kind in ['KEYED', 'RESOLUTION'] and materialized != 'ephemeral' %}
        {{ exceptions.raise_compiler_error(kind ~ ' must be materialized as ephemeral') }}
    {% endif %}
    {% if kind == 'CASE_VIEW' and materialized != 'view' %}
        {{ exceptions.raise_compiler_error('CASE_VIEW must be materialized as view') }}
    {% endif %}
    {% if materialized == 'incremental' and spec.get('incremental') is none %}
        {{ exceptions.raise_compiler_error('incremental materialization requires spec.incremental') }}
    {% endif %}
    {{ return(materialized) }}
{%- endmacro %}

{% macro _layer_generator_render_list(values) -%}
[{% for value in values %}'{{ value | replace("'", "''") }}'{% if not loop.last %}, {% endif %}{% endfor %}]
{%- endmacro %}

{% macro _layer_generator_render_config(spec, normalized) -%}
    {% set materialized = _layer_generator_materialization(spec, normalized['kind']) %}
    {% set default_tags = {
        'STAGING': ['layer1'], 'QUARANTINE': ['layer1', 'quarantine', 'personal_data'],
        'CONTROL': ['deletion_control', 'personal_data_control'],
        'MAPPING': ['priva_map', 'personal_data'], 'KEYED': ['layer2', 'personal_data'],
        'RESOLUTION': ['layer2', 'personal_data'], 'PUBLISHED': ['layer2', 'personal_data'],
        'DIMENSION': ['layer3_dimensions'], 'DATE_DIMENSION': ['layer3_dimensions', 'non_personal_data'],
        'FACT': ['layer3_facts', 'personal_data'], 'CASE_VIEW': ['case_views']
    } %}
    {% set tags = [] %}
    {% for tag in default_tags[normalized['kind']] + spec.get('tags', []) %}
        {% if tag not in tags %}{% do tags.append(tag) %}{% endif %}
    {% endfor %}
{{ '{{' }} config(
    materialized='{{ materialized }}',
    tags={{ _layer_generator_render_list(tags) }}{% if materialized == 'incremental' %},
    incremental_strategy='{{ spec['incremental'].get('strategy', 'merge') }}',
    unique_key={{ spec['incremental'].get('unique_key') | tojson }},
    on_schema_change='{{ spec['incremental'].get('on_schema_change', 'fail') }}'{% endif %}{% if spec.get('databricks_tags') %},
    databricks_tags={{ spec.get('databricks_tags') | tojson }}{% endif %}
) {{ '}}' }}
{%- endmacro %}

{% macro _layer_generator_render_expression(column, source_alias) -%}
    {% if column.get('key') is not none %}
        {% set key = column.get('key') %}
{{ '{{' }} personal_data_key(
    {{ key['expression'] | tojson }},
    '{{ key['domain'] | replace("'", "''") }}',
    '{{ key.get('kind', 'text') | replace("'", "''") }}'
) {{ '}}' }} as {{ column['name'] }}
    {% elif column.get('expression') is not none %}
{{ column.get('expression') }} as {{ column['name'] }}
    {% else %}
{{ source_alias }}.{{ column['name'] }}
    {% endif %}
{%- endmacro %}

{% macro _layer_generator_render_projection(columns, source_alias, indent='        ') -%}
    {% for column in columns %}
{{ indent }}{{ _layer_generator_render_expression(column, source_alias) | trim }}{% if not loop.last %},{% endif %}
    {% endfor %}
{%- endmacro %}

{% macro _layer_generator_render_joins(joins) -%}
    {% for join in joins %}
{{ join.get('type', 'inner') | lower }} join {% if join.get('model') is not none %}{{ '{{' }} ref('{{ join['model'] }}') {{ '}}' }}{% else %}{{ join['cte'] }}{% endif %} as {{ join['alias'] }}{% if join.get('type', 'inner') | lower != 'cross' %}
        on {{ join.get('on', join.get(true)) }}{% endif %}
    {% endfor %}
{%- endmacro %}

{% macro _layer_generator_render_where(predicates) -%}
    {% if predicates | length > 0 %}
    where
        {% for predicate in predicates %}
        {{ predicate }}{% if not loop.last %}
        and{% endif %}
        {% endfor %}
    {% endif %}
{%- endmacro %}

{% macro _layer_generator_render_date_dimension(spec) -%}
with calendar_days as (
    select explode(
        sequence(
            cast('{{ '{{' }} var("{{ spec.get('start_var', 'date_dimension_start') }}") {{ '}}' }}' as date),
            cast('{{ '{{' }} var("{{ spec.get('end_var', 'date_dimension_end') }}") {{ '}}' }}' as date),
            interval 1 day
        )
    ) as date_day
)

select
    cast(date_format(date_day, 'yyyyMMdd') as int) as date_key,
    date_day,
    year(date_day) as calendar_year,
    quarter(date_day) as calendar_quarter,
    month(date_day) as month_number,
    date_format(date_day, 'MMMM') as month_name,
    day(date_day) as day_of_month,
    dayofweek(date_day) as day_of_week,
    date_format(date_day, 'EEEE') as day_name,
    weekofyear(date_day) as iso_week_number,
    dayofweek(date_day) in (1, 7) as is_weekend
from calendar_days
{%- endmacro %}

{% macro _layer_generator_validate_deletion(deletion, kind, column_names) -%}
    {% if deletion is not mapping %}
        {{ exceptions.raise_compiler_error(kind ~ ' requires spec.deletion mapping') }}
    {% endif %}
    {% set allowed = [
        'model_type', 'customer_key_column', 'customer_key_expression', 'customer_key_domain',
        'customer_key_kind', 'special_replacement_columns', 'erased_flag_column',
        'source_is_mode_annotated', 'source_is_policy_applied', 'deletion_mode_column',
        'additional_predicate', 'register_target'
    ] %}
    {% do _layer_generator_validate_keys(deletion, allowed, 'spec.deletion') %}
    {% set model_type = deletion.get('model_type', kind) | upper %}
    {% do _validate_customer_deletion_model_type(model_type) %}
    {% set fixed_model_types = {
        'QUARANTINE': 'QUARANTINE', 'MAPPING': 'MAPPING', 'DIMENSION': 'DIMENSION',
        'FACT': 'FACT', 'CASE_VIEW': 'CASE_VIEW'
    } %}
    {% if kind in fixed_model_types and model_type != fixed_model_types[kind] %}
        {{ exceptions.raise_compiler_error(
            kind ~ ' deletion.model_type must be ' ~ fixed_model_types[kind]
        ) }}
    {% endif %}
    {% set customer_key_column = deletion.get('customer_key_column', 'customer_key') %}
    {% do _validate_deletion_policy_identifier(customer_key_column, 'spec.deletion.customer_key_column') %}
    {% if deletion.get('customer_key_expression') is not none and deletion.get('customer_key_domain') is not none %}
        {{ exceptions.raise_compiler_error(
            'spec.deletion accepts customer_key_expression or customer_key_domain, not both'
        ) }}
    {% endif %}
    {% if deletion.get('customer_key_domain') is not none %}
        {% do _layer_generator_require_string(
            deletion.get('customer_key_domain'), 'spec.deletion.customer_key_domain'
        ) %}
        {% do _validate_personal_data_kind(
            deletion.get('customer_key_kind', 'text'), 'spec.deletion.customer_key_kind'
        ) %}
    {% endif %}
    {% if deletion.get('customer_key_expression') is not none %}
        {% do _layer_generator_require_string(
            deletion.get('customer_key_expression'), 'spec.deletion.customer_key_expression'
        ) %}
    {% endif %}
    {% if customer_key_column not in column_names %}
        {% if model_type != 'CASE_VIEW' or deletion.get('erased_flag_column') is none %}
            {{ exceptions.raise_compiler_error(
                'spec.deletion.customer_key_column is not present in columns: ' ~ customer_key_column
            ) }}
        {% endif %}
    {% endif %}
    {% if deletion.get('special_replacement_columns') is not none %}
        {% set replacements = _normalize_customer_deletion_generator_list(
            deletion.get('special_replacement_columns'),
            'spec.deletion.special_replacement_columns'
        ) %}
        {% for replacement in replacements %}
            {% if replacement not in column_names %}
                {{ exceptions.raise_compiler_error(
                    'replacement column is not present in columns: ' ~ replacement
                ) }}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% if model_type == 'FACT' %}
        {% if deletion.get('special_replacement_columns') is none %}
            {{ exceptions.raise_compiler_error(
                'FACT deletion requires special_replacement_columns'
            ) }}
        {% endif %}
        {% if customer_key_column not in deletion.get('special_replacement_columns') %}
            {{ exceptions.raise_compiler_error(
                'FACT special_replacement_columns must include customer_key_column'
            ) }}
        {% endif %}
        {% do _validate_deletion_policy_identifier(
            deletion.get('erased_flag_column'), 'spec.deletion.erased_flag_column'
        ) %}
        {% if deletion.get('erased_flag_column') not in column_names %}
            {{ exceptions.raise_compiler_error(
                'FACT erased_flag_column must be present in columns so the enforced contract includes it'
            ) }}
        {% endif %}
    {% elif deletion.get('special_replacement_columns') is not none %}
        {{ exceptions.raise_compiler_error(
            'special_replacement_columns is supported only for FACT deletion'
        ) }}
    {% endif %}
    {% if model_type == 'CASE_VIEW' and deletion.get('erased_flag_column') is none
        and customer_key_column not in column_names %}
        {{ exceptions.raise_compiler_error(
            'CASE_VIEW deletion requires an erased_flag_column or visible customer_key_column'
        ) }}
    {% endif %}
    {% if deletion.get('erased_flag_column') is not none %}
        {% do _validate_deletion_policy_identifier(
            deletion.get('erased_flag_column'), 'spec.deletion.erased_flag_column'
        ) %}
    {% endif %}
    {% for boolean_key in [
        'source_is_mode_annotated', 'source_is_policy_applied', 'register_target'
    ] %}
        {% if deletion.get(boolean_key) is not none and deletion.get(boolean_key) is not boolean %}
            {{ exceptions.raise_compiler_error('spec.deletion.' ~ boolean_key ~ ' must be boolean') }}
        {% endif %}
    {% endfor %}
    {{ return(model_type) }}
{%- endmacro %}

{% macro _layer_generator_render_deletion_call(spec, normalized) -%}
    {% set deletion = spec.get('deletion') %}
    {% set column_names = _layer_generator_normalize_columns(normalized['columns']) %}
    {% set model_type = _layer_generator_validate_deletion(
        deletion, normalized['kind'], column_names
    ) %}
    {% set customer_key_column = deletion.get('customer_key_column', 'customer_key') %}
    {% set output_column_names = column_names %}
    {% if model_type == 'FACT' and not deletion.get('source_is_policy_applied', false) %}
        {% set output_column_names = [] %}
        {% for column_name in column_names %}
            {% if column_name != deletion.get('erased_flag_column') %}
                {% do output_column_names.append(column_name) %}
            {% endif %}
        {% endfor %}
    {% endif %}
{{ '{{' }} generate_customer_deletion_model(
    model_name='{{ spec['model_name'] }}',
    model_type='{{ model_type }}',
    source_relation='generated_rows',
    primary_key={{ _layer_generator_render_list(normalized['primary_keys']) }},
    output_columns={{ _layer_generator_render_list(output_column_names) }},
    customer_key_column='{{ customer_key_column }}'{% if deletion.get('customer_key_domain') is not none %},
    customer_key_expression=personal_data_key(
        'source_rows.{{ customer_key_column }}',
        '{{ deletion.get('customer_key_domain') | replace("'", "''") }}',
        '{{ deletion.get('customer_key_kind', 'text') | replace("'", "''") }}'
    ){% elif deletion.get('customer_key_expression') is not none %},
    customer_key_expression={{ deletion.get('customer_key_expression') | tojson }}{% endif %}{% if deletion.get('special_replacement_columns') is not none %},
    special_replacement_columns={{ _layer_generator_render_list(deletion.get('special_replacement_columns')) }}{% endif %}{% if deletion.get('erased_flag_column') is not none %},
    erased_flag_column='{{ deletion.get('erased_flag_column') }}'{% elif model_type == 'CASE_VIEW' %},
    erased_flag_column=none{% endif %}{% if deletion.get('source_is_mode_annotated', false) %},
    source_is_mode_annotated=true{% endif %}{% if deletion.get('source_is_policy_applied', false) %},
    source_is_policy_applied=true{% endif %}{% if deletion.get('deletion_mode_column') is not none %},
    deletion_mode_column='{{ deletion.get('deletion_mode_column') }}'{% endif %}{% if model_type == 'CASE_VIEW' %},
    additional_predicate={{ deletion.get('additional_predicate', 'case_access_predicate()') }}{% endif %}
) {{ '}}' }}
{%- endmacro %}

{% macro _layer_generator_render_model_sql(spec, forced_layer=none) -%}
    {% set normalized = _layer_generator_normalize_spec(spec, forced_layer) %}
    {% set kind = normalized['kind'] %}
    {% set source_alias = spec.get('source_alias', 'source_rows') %}
    {% set ctes = spec.get('ctes', []) %}
    {% set joins = spec.get('joins', []) %}
    {% set predicates = spec.get('where', []) %}
    {% set materialized = _layer_generator_materialization(spec, kind) %}
    {% set projection_columns = normalized['columns'] + normalized['helper_columns'] %}
    {% if spec.get('deletion') is not none
        and spec.get('deletion').get('model_type', kind) | upper == 'FACT'
        and not spec.get('deletion').get('source_is_policy_applied', false) %}
        {% set fact_projection_columns = [] %}
        {% for column in projection_columns %}
            {% if column['name'] != spec.get('deletion').get('erased_flag_column') %}
                {% do fact_projection_columns.append(column) %}
            {% endif %}
        {% endfor %}
        {% set projection_columns = fact_projection_columns %}
    {% endif %}
    {% set sql %}
{{ _layer_generator_render_config(spec, normalized) }}

        {% if kind == 'DATE_DIMENSION' %}
{{ _layer_generator_render_date_dimension(spec) }}
        {% else %}
with
            {% for cte in ctes %}
{{ cte['name'] }} as (
{{ cte['sql'] }}
),
            {% endfor %}
generated_rows as (
    select
{{ _layer_generator_render_projection(
    projection_columns, source_alias
) }}
    from {% if spec.get('source_model') is not none %}{{ '{{' }} ref('{{ spec['source_model'] }}') {{ '}}' }}{% else %}{{ spec['source_cte'] }}{% endif %} as {{ source_alias }}
{{ _layer_generator_render_joins(joins) }}
{{ _layer_generator_render_where(predicates) }}
)

            {% if kind == 'DIMENSION' and spec.get('erased_member') is not none %}
                {% set erased_member = spec.get('erased_member') %}
                {% for column in normalized['columns'] %}
                    {% if column['name'] not in erased_member %}
                        {{ exceptions.raise_compiler_error(
                            'spec.erased_member is missing column: ' ~ column['name']
                        ) }}
                    {% endif %}
                {% endfor %}
                {% if spec.get('deletion') is not none %}
, governed_rows as (
{{ _layer_generator_render_deletion_call(spec, normalized) }}
)
                {% endif %}
, erased_subject_member as (
    select
                {% for column in normalized['columns'] %}
        {{ erased_member[column['name']] }} as {{ column['name'] }}{% if not loop.last %},{% endif %}
                {% endfor %}
)

select * from {% if spec.get('deletion') is not none %}governed_rows{% else %}generated_rows{% endif %}
union all
select * from erased_subject_member
            {% elif kind in ['QUARANTINE', 'MAPPING', 'FACT', 'CASE_VIEW'] or spec.get('deletion') is not none %}
{{ _layer_generator_render_deletion_call(spec, normalized) }}
            {% else %}
select * from generated_rows
            {% endif %}
        {% endif %}
    {% endset %}
    {% set clean_sql = modules.re.sub('(?m)[ \\t]+$', '', sql) %}
    {% set clean_sql = modules.re.sub('\n{3,}', '\n\n', clean_sql) %}
    {{ return(clean_sql | trim) }}
{%- endmacro %}

{% macro _layer_generator_render_schema_yaml(spec, forced_layer=none) -%}
    {% set normalized = _layer_generator_normalize_spec(spec, forced_layer) %}
    {% set materialized = _layer_generator_materialization(spec, normalized['kind']) %}
    {% set tags = spec.get('tags', []) %}
    {% set lines = ['version: 2', '', 'models:', '  - name: ' ~ spec['model_name']] %}
    {% do lines.append('    description: >') %}
    {% do lines.append('      ' ~ spec['description'] | replace('\n', ' ')) %}
    {% do lines.append('    config:') %}
    {% do lines.append('      contract:') %}
    {% do lines.append('        enforced: ' ~ ('false' if materialized == 'ephemeral' else 'true')) %}
    {% if tags | length > 0 %}{% do lines.append('      tags: ' ~ tags) %}{% endif %}
    {% do lines.append('    columns:') %}
    {% for column in normalized['columns'] %}
        {% do lines.append('      - name: ' ~ column['name']) %}
        {% do lines.append('        data_type: ' ~ column['data_type']) %}
        {% do lines.append('        description: >') %}
        {% do lines.append('          ' ~ column['description'] | replace('\n', ' ')) %}
        {% if column.get('databricks_tags') is not none %}
            {% do lines.append('        databricks_tags:') %}
            {% for tag_name, tag_value in column.get('databricks_tags').items() %}
                {% do lines.append(
                    '          ' ~ tag_name | tojson ~ ': ' ~ tag_value | tojson
                ) %}
            {% endfor %}
        {% endif %}
        {% if column.get('column_mask') is not none %}
            {% do lines.append('        column_mask:') %}
            {% do lines.append(
                '          function: ' ~ column.get('column_mask').get('function') | tojson
            ) %}
            {% if column.get('column_mask').get('using_columns') is not none %}
                {% do lines.append(
                    '          using_columns: '
                    ~ column.get('column_mask').get('using_columns') | tojson
                ) %}
            {% endif %}
        {% endif %}
        {% set tests = [] %}
        {% if column['name'] in normalized['primary_keys'] %}{% do tests.append('not_null') %}{% endif %}
        {% if normalized['primary_keys'] | length == 1 and column['name'] in normalized['primary_keys'] %}
            {% do tests.append('unique') %}
        {% endif %}
        {% for test_name in column.get('tests', []) %}
            {% if test_name not in tests %}{% do tests.append(test_name) %}{% endif %}
        {% endfor %}
        {% if tests | length > 0 %}{% do lines.append('        data_tests: ' ~ tests) %}{% endif %}
    {% endfor %}
    {{ return(lines | join('\n')) }}
{%- endmacro %}

{% macro _layer_generator_emit(spec, forced_layer=none) -%}
    {% set normalized = _layer_generator_normalize_spec(spec, forced_layer) %}
    {% set model_sql = _layer_generator_render_model_sql(spec, forced_layer) %}
    {% set schema_yaml = _layer_generator_render_schema_yaml(spec, forced_layer) %}
    {% do log('\nMODEL SQL\n' ~ model_sql, info=true) %}
    {% do log('\nSCHEMA YAML\n' ~ schema_yaml, info=true) %}
    {% if spec.get('deletion') is not none and spec.get('deletion').get('register_target', false) %}
        {% set model_type = spec.get('deletion').get('model_type', normalized['kind']) | upper %}
        {% set materialized = _layer_generator_materialization(spec, normalized['kind']) %}
        {% if model_type == 'CASE_VIEW' %}
            {% set target_kind = 'VIEW' %}
        {% elif materialized in ['table', 'incremental'] %}
            {% set target_kind = 'TABLE' %}
        {% else %}
            {{ exceptions.raise_compiler_error(
                'deletion.register_target requires a physical table/incremental model '
                ~ 'or a CASE_VIEW view; received materialized=' ~ materialized
            ) }}
        {% endif %}
        {% set target_row = generate_customer_deletion_target_row(
            target_layer=normalized['layer'],
            model_name=spec['model_name'],
            model_type=model_type,
            target_kind=target_kind
        ) %}
        {% do log(
            '\nTARGET REGISTRY ENTRY\n' ~ {
                'target_layer': normalized['layer'],
                'model_name': spec['model_name'],
                'model_type': model_type,
                'target_kind': target_kind
            },
            info=true
        ) %}
        {% do log('\nDERIVED TARGET ROW\n' ~ target_row | trim, info=true) %}
    {% endif %}
    {{ return('Generated ' ~ normalized['layer'] ~ ' scaffold for ' ~ spec['model_name']) }}
{%- endmacro %}

{% macro generate_layer_model_scaffold(spec) -%}
    {{ return(_layer_generator_emit(spec)) }}
{%- endmacro %}

{% macro generate_layer1_model(spec) -%}
    {{ return(_layer_generator_emit(spec, 'layer1')) }}
{%- endmacro %}

{% macro generate_priva_map_model(spec) -%}
    {{ return(_layer_generator_emit(spec, 'priva_map')) }}
{%- endmacro %}

{% macro generate_layer2_model(spec) -%}
    {{ return(_layer_generator_emit(spec, 'layer2')) }}
{%- endmacro %}

{% macro generate_layer3_model(spec) -%}
    {{ return(_layer_generator_emit(spec, 'layer3')) }}
{%- endmacro %}

{% macro generate_layer3_case_model(spec) -%}
    {{ return(_layer_generator_emit(spec, 'layer3_case')) }}
{%- endmacro %}

{% macro generate_all_layer_models(specs) -%}
    {% do _layer_generator_require_sequence(specs, 'specs') %}
    {% set generated = [] %}
    {% for spec in specs %}
        {% do generated.append(_layer_generator_emit(spec)) %}
    {% endfor %}
    {{ return('Generated ' ~ generated | length ~ ' layer model scaffolds') }}
{%- endmacro %}
