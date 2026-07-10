{% macro hash_personal_data_expression(canonical_value, domain, hash_version, pepper) -%}
  case
    when {{ canonical_value }} is null then null
    else concat(
      {{ hash_version }},
      ':',
      sha2(
        concat(
          'purpose_length=',
          cast(length('gdpr_personal_data_pseudonym') as string),
          '|purpose=gdpr_personal_data_pseudonym|',
          'version_length=', cast(length({{ hash_version }}) as string),
          '|version=', {{ hash_version }},
          '|domain_length=', cast(length({{ domain }}) as string),
          '|domain=', {{ domain }},
          '|value_length=', cast(length({{ canonical_value }}) as string),
          '|value=', {{ canonical_value }},
          '|pepper_length=', cast(length({{ pepper }}) as string),
          '|pepper=', {{ pepper }}
        ),
        256
      )
    )
  end
{%- endmacro %}

{% macro canonicalize_personal_data(value_expression, kind='text') -%}
  {%- if kind == 'ssn' -%}
    nullif(regexp_replace(trim(cast({{ value_expression }} as string)), '[^0-9]', ''), '')
  {%- elif kind == 'phone' -%}
    nullif(regexp_replace(trim(cast({{ value_expression }} as string)), '[^0-9]', ''), '')
  {%- elif kind == 'date' -%}
    date_format(cast({{ value_expression }} as date), 'yyyy-MM-dd')
  {%- else -%}
    nullif(lower(regexp_replace(trim(cast({{ value_expression }} as string)), '\\s+', ' ')), '')
  {%- endif -%}
{%- endmacro %}

{% macro personal_data_key(value_expression, domain, kind='text') -%}
  {{ function('pseudonymize_personal_data_v1') }}(
    {{ canonicalize_personal_data(value_expression, kind) }},
    '{{ domain | replace("'", "''") }}'
  )
{%- endmacro %}
