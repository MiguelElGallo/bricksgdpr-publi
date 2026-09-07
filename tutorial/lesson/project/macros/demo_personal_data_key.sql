{#
  STEP 3 support: canonicalize each value, frame it with its domain and lengths, then hash it.
  This deterministic browser key uses a public teaching constant. It does not reproduce the
  secret-backed Databricks pseudonymization function or provide a security control.
#}

{% macro demo_canonicalize_personal_data(value_expression, kind='text') -%}
  {%- if kind is not string or kind | lower not in ['text', 'ssn', 'phone', 'date'] -%}
    {{ exceptions.raise_compiler_error('kind must be text, ssn, phone, or date') }}
  {%- endif -%}
  {%- set kind = kind | lower -%}
  {%- if kind == 'ssn' -%}
    case
      when {{ value_expression }} is null then null
      when regexp_full_match(trim(cast({{ value_expression }} as varchar)),
          '([0-9]{9}|[0-9]{3}-[0-9]{2}-[0-9]{4})')
        then replace(trim(cast({{ value_expression }} as varchar)), '-', '')
      else error('Invalid synthetic SSN: expected nine digits or XXX-XX-XXXX')
    end
  {%- elif kind == 'phone' -%}
    case
      when {{ value_expression }} is null then null
      when regexp_full_match(trim(cast({{ value_expression }} as varchar)), '[+][1-9][0-9 ()-]*')
        and length(regexp_replace(cast({{ value_expression }} as varchar), '[^0-9]', '', 'g'))
          between 7 and 15
        then regexp_replace(cast({{ value_expression }} as varchar), '[^0-9]', '', 'g')
      else error('Invalid phone: supply an explicit international + prefix and 7-15 digits')
    end
  {%- elif kind == 'date' -%}
    strftime(cast({{ value_expression }} as date), '%Y-%m-%d')
  {%- else -%}
    nullif(
      lower(
        regexp_replace(
          trim(cast({{ value_expression }} as varchar)),
          '[[:space:]]+',
          ' ',
          'g'
        )
      ),
      ''
    )
  {%- endif -%}
{%- endmacro %}

{% macro demo_personal_data_key(value_expression, domain, kind='text') -%}
  {%- set canonical_value = demo_canonicalize_personal_data(value_expression, kind) -%}
  {%- set escaped_domain = domain | replace("'", "''") -%}
  {# Preserve nulls; otherwise include purpose, version, domain, value, and public demo constant. #}
  case
    when {{ canonical_value }} is null then null
    else concat(
      'demo-v1:',
      sha256(
        concat(
          'purpose_length=',
          cast(length('gdpr_personal_data_pseudonym') as varchar),
          '|purpose=gdpr_personal_data_pseudonym|',
          'version_length=', cast(length('demo-v1') as varchar),
          '|version=demo-v1|',
          'domain_length=', cast(length('{{ escaped_domain }}') as varchar),
          '|domain={{ escaped_domain }}|',
          'value_length=', cast(length({{ canonical_value }}) as varchar),
          '|value=', {{ canonical_value }},
          '|pepper_length=', cast(length('public-browser-demo-not-secret') as varchar),
          '|pepper=public-browser-demo-not-secret'
        )
      )
    )
  end
{%- endmacro %}
