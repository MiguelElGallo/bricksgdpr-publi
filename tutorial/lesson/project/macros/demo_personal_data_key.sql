{#
  Browser lesson only: this deterministic key uses a public teaching constant. It does not
  reproduce the secret-backed Databricks pseudonymization function or provide a security control.
#}

{% macro demo_canonicalize_personal_data(value_expression, kind='text') -%}
  {%- if kind in ['ssn', 'phone'] -%}
    nullif(
      regexp_replace(trim(cast({{ value_expression }} as varchar)), '[^0-9]', '', 'g'),
      ''
    )
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
