{% macro _validate_deletion_policy_identifier(value, argument_name) -%}
    {% if value is not string or not modules.re.match('^[A-Za-z_][A-Za-z0-9_]*$', value) %}
        {{ exceptions.raise_compiler_error(
            argument_name ~ ' must be a simple SQL identifier; received: ' ~ value
        ) }}
    {% endif %}
{%- endmacro %}

{% macro _validate_deletion_policy_columns(output_columns) -%}
    {% if output_columns is string or output_columns is not sequence or output_columns | length == 0 %}
        {{ exceptions.raise_compiler_error('output_columns must be a non-empty list of identifiers') }}
    {% endif %}
    {% set seen = [] %}
    {% for column_name in output_columns %}
        {% do _validate_deletion_policy_identifier(column_name, 'output_columns[' ~ loop.index0 ~ ']') %}
        {% if column_name in seen %}
            {{ exceptions.raise_compiler_error('output_columns contains duplicate: ' ~ column_name) }}
        {% endif %}
        {% do seen.append(column_name) %}
    {% endfor %}
{%- endmacro %}

{% macro attach_customer_deletion_mode(
    source_relation,
    customer_key_expression,
    output_columns,
    deletion_relation,
    source_alias='source_rows'
) -%}
    {% do _validate_deletion_policy_columns(output_columns) %}
    {% do _validate_deletion_policy_identifier(source_alias, 'source_alias') %}
    {% if customer_key_expression is not string or customer_key_expression | trim == '' %}
        {{ exceptions.raise_compiler_error('customer_key_expression must be non-empty SQL') }}
    {% endif %}
select
    {% for column_name in output_columns %}
    {{ source_alias }}.{{ column_name }},
    {% endfor %}
    deletion_keys.deletion_mode
from {{ source_relation }} as {{ source_alias }}
left join {{ deletion_relation }} as deletion_keys
    on {{ customer_key_expression }} = deletion_keys.customer_ssn
{%- endmacro %}

{% macro apply_customer_deletion_policy(
    source_relation,
    output_columns,
    special_behavior,
    special_replacements=none,
    erased_flag_column=none,
    deletion_mode_column='deletion_mode',
    source_alias='policy_rows'
) -%}
    {% do _validate_deletion_policy_columns(output_columns) %}
    {% do _validate_deletion_policy_identifier(source_alias, 'source_alias') %}
    {% do _validate_deletion_policy_identifier(deletion_mode_column, 'deletion_mode_column') %}
    {% set special_behavior = special_behavior | upper %}
    {% if special_behavior not in ['DELETE', 'REPLACE'] %}
        {{ exceptions.raise_compiler_error(
            'special_behavior must be DELETE or REPLACE; received: ' ~ special_behavior
        ) }}
    {% endif %}
    {% if special_replacements is none %}
        {% set special_replacements = {} %}
    {% endif %}
    {% if special_replacements is not mapping %}
        {{ exceptions.raise_compiler_error('special_replacements must be a column-to-SQL mapping') }}
    {% endif %}
    {% for column_name, replacement_expression in special_replacements.items() %}
        {% do _validate_deletion_policy_identifier(column_name, 'special_replacements key') %}
        {% if column_name not in output_columns %}
            {{ exceptions.raise_compiler_error(
                'special_replacements key is not in output_columns: ' ~ column_name
            ) }}
        {% endif %}
        {% if replacement_expression is not string or replacement_expression | trim == '' %}
            {{ exceptions.raise_compiler_error(
                'special replacement for ' ~ column_name ~ ' must be non-empty SQL'
            ) }}
        {% endif %}
    {% endfor %}
    {% if special_behavior == 'REPLACE' %}
        {% if special_replacements | length == 0 or erased_flag_column is none %}
            {{ exceptions.raise_compiler_error(
                'REPLACE requires special_replacements and erased_flag_column'
            ) }}
        {% endif %}
        {% do _validate_deletion_policy_identifier(erased_flag_column, 'erased_flag_column') %}
        {% if erased_flag_column in output_columns %}
            {{ exceptions.raise_compiler_error(
                'erased_flag_column must not duplicate an output column: ' ~ erased_flag_column
            ) }}
        {% endif %}
    {% elif special_replacements | length > 0 or erased_flag_column is not none %}
        {{ exceptions.raise_compiler_error(
            'DELETE does not accept special replacements or an erased flag'
        ) }}
    {% endif %}
select
    {% for column_name in output_columns %}
        {% if column_name in special_replacements %}
    case
        when {{ source_alias }}.{{ deletion_mode_column }} = 'SPECIAL_DELETION'
            then {{ special_replacements[column_name] }}
        else {{ source_alias }}.{{ column_name }}
    end as {{ column_name }}{% if not loop.last or special_behavior == 'REPLACE' %},{% endif %}
        {% else %}
    {{ source_alias }}.{{ column_name }}{% if not loop.last or special_behavior == 'REPLACE' %},{% endif %}
        {% endif %}
    {% endfor %}
    {% if special_behavior == 'REPLACE' %}
    case
        when {{ source_alias }}.{{ deletion_mode_column }} = 'SPECIAL_DELETION' then true
        else false
    end as {{ erased_flag_column }}
    {% endif %}
from {{ source_relation }} as {{ source_alias }}
where
    {% if special_behavior == 'DELETE' %}
    {{ source_alias }}.{{ deletion_mode_column }} is null
    {% else %}
    (
    {{ source_alias }}.{{ deletion_mode_column }} is null
    or {{ source_alias }}.{{ deletion_mode_column }} = 'SPECIAL_DELETION'
    )
    {% endif %}
{%- endmacro %}
