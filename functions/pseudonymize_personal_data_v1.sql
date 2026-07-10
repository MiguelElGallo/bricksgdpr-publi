{% if var('personal_data_hash_version') != 'v1' %}
  {% do exceptions.raise_compiler_error(
      "pseudonymize_personal_data_v1 requires personal_data_hash_version=v1"
  ) %}
{% endif %}
{% if var('personal_data_secret_key') != 'pepper_v1' %}
  {% do exceptions.raise_compiler_error(
      "pseudonymize_personal_data_v1 requires personal_data_secret_key=pepper_v1"
  ) %}
{% endif %}
{% if var('personal_data_secret_scope') != 'bricksgdpr' %}
  {% do exceptions.raise_compiler_error(
      "pseudonymize_personal_data_v1 requires personal_data_secret_scope=bricksgdpr"
  ) %}
{% endif %}

{% set hash_version = var('personal_data_hash_version') | replace("'", "''") %}
{% set secret_scope = 'bricksgdpr' %}
{% set secret_key = 'pepper_v1' %}

{{ hash_personal_data_expression(
    'canonical_value',
    'domain',
    "'" ~ hash_version ~ "'",
    "secret('" ~ secret_scope ~ "', '" ~ secret_key ~ "')"
) }}
