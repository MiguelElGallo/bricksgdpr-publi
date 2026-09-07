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

{% macro _validate_personal_data_kind(kind, argument_name='kind') -%}
  {%- if kind is not string or kind | lower not in ['text', 'ssn', 'phone', 'date'] -%}
    {{ exceptions.raise_compiler_error(
      argument_name ~ " must be one of text, ssn, phone, or date; received: " ~ kind
    ) }}
  {%- endif -%}
  {{ return(kind | lower) }}
{%- endmacro %}

{% macro canonicalize_personal_data(value_expression, kind='text') -%}
  {%- set normalized_kind = _validate_personal_data_kind(kind) -%}
  {%- if normalized_kind == 'ssn' -%}
    case
      when {{ value_expression }} is null then null
      when trim(cast({{ value_expression }} as string)) rlike '^([0-9]{9}|[0-9]{3}-[0-9]{2}-[0-9]{4})$'
        then regexp_replace(trim(cast({{ value_expression }} as string)), '-', '')
      else raise_error('Invalid synthetic SSN: expected nine digits or XXX-XX-XXXX')
    end
  {%- elif normalized_kind == 'phone' -%}
    case
      when {{ value_expression }} is null then null
      when trim(cast({{ value_expression }} as string)) rlike '^[+][1-9][0-9 ()-]*$'
        and length(regexp_replace(cast({{ value_expression }} as string), '[^0-9]', '')) between 7 and 15
        then regexp_replace(cast({{ value_expression }} as string), '[^0-9]', '')
      else raise_error('Invalid phone: supply an explicit international + prefix and 7-15 digits')
    end
  {%- elif normalized_kind == 'date' -%}
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
