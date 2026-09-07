{% macro operations_fixture_setup() %}
  {% set history = deletion_evidence_relation('control_history') %}
  {% set events = deletion_evidence_relation('execution_events') %}
  {% do run_query('create catalog ' ~ adapter.quote(var('evidence_catalog')) ~ " comment 'bricksgdpr-operations-fixture-" ~ deletion_execution_id() ~ "'") %}
  {% do bootstrap_deletion_evidence() %}
  {% do run_query('create schema ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(target.schema) ~ " comment 'bricksgdpr-operations-fixture-" ~ deletion_execution_id() ~ "'") %}
  {% do run_query('create table ' ~ ref('customer_deletion_requests') ~ " using delta as select 'request-1' as deletion_request_id, 'synthetic-1' as customer_id, '900-00-0001' as customer_ssn, current_timestamp() as source_deleted_at, current_timestamp() as detected_at, 'DETECTED' as detection_status") %}
  {% do run_query(archive_deletion_control(ref('customer_deletion_requests'))) %}
  {% do run_query(archive_deletion_control(ref('customer_deletion_requests'))) %}
  {% if run_query('select count(*) from ' ~ history).rows[0][0] != 1 %}
    {{ exceptions.raise_compiler_error('Archive replay duplicated evidence') }}
  {% endif %}
  {% do run_query(guard_deletion_control(ref('customer_deletion_requests'))) %}
  {% do run_query('drop table ' ~ ref('customer_deletion_requests')) %}
{% endmacro %}

{% macro operations_fixture_restore() %}
  {% do restore_deletion_control('customer_deletion_requests') %}
  {% do run_query(guard_deletion_control(ref('customer_deletion_requests'))) %}
  {% if run_query('select count(*) from ' ~ ref('customer_deletion_requests')).rows[0][0] != 1 %}
    {{ exceptions.raise_compiler_error('Recovery lost an archived request') }}
  {% endif %}
{% endmacro %}

{% macro operations_fixture_truncate() %}
  {% do run_query('delete from ' ~ ref('customer_deletion_requests')) %}
  {% do run_query(guard_deletion_control(ref('customer_deletion_requests'))) %}
{% endmacro %}

{% macro operations_fixture_missing() %}
  {% do run_query(guard_deletion_control(ref('customer_deletion_requests'))) %}
{% endmacro %}

{% macro operations_fixture_cleanup() %}
  {% set marker = 'bricksgdpr-operations-fixture-' ~ deletion_execution_id() %}
  {% set catalog = var('evidence_catalog') %}
  {% set owned_catalog = run_query("select count(*) from system.information_schema.catalogs where catalog_name = '" ~ catalog ~ "' and comment = '" ~ marker ~ "'") %}
  {% if owned_catalog.rows[0][0] == 1 %}
    {% do run_query('drop catalog ' ~ adapter.quote(catalog) ~ ' cascade') %}
  {% endif %}
  {% set owned_schema = run_query("select count(*) from system.information_schema.schemata where catalog_name = '" ~ target.database ~ "' and schema_name = '" ~ target.schema ~ "' and comment = '" ~ marker ~ "'") %}
  {% if owned_schema.rows[0][0] == 1 %}
    {% do run_query('drop schema ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(target.schema) ~ ' cascade') %}
  {% endif %}
{% endmacro %}

{% macro operations_fixture_status() %}
  {% do run_query('create table ' ~ ref('int_customer_deletion_plan') ~ " using delta as select 'revision-1' as decision_revision_id, 'v1:synthetic' as customer_key, 'dim_customer' as target_relation, 'SPECIAL_DELETION' as deletion_mode, 'CUSTOMER_DELETION_V1' as deletion_policy_version, 'layer3' as target_layer") %}
  {% do begin_deletion_execution() %}
  {% do append_deletion_event('dim_customer', 'COMPLETED') %}
  {% do record_deletion_failure() %}
  {% set events = deletion_evidence_relation('execution_events') %}
  {% set counts = run_query("select count_if(status='PENDING'), count_if(status='COMPLETED'), count_if(status='FAILED'), count_if(status='VERIFIED') from " ~ events) %}
  {% if counts.rows[0] | list != [1, 1, 1, 0] %}
    {{ exceptions.raise_compiler_error('Execution status lost failure or claimed unverified completion') }}
  {% endif %}
{% endmacro %}

{% macro operations_fixture_invalid_ssn() %}
  {% do run_query("select " ~ canonicalize_personal_data("'900A000001'", 'ssn')) %}
{% endmacro %}

{% macro operations_fixture_invalid_phone() %}
  {% do run_query("select " ~ canonicalize_personal_data("'3585550101x2'", 'phone')) %}
{% endmacro %}

{% macro operations_fixture_partial_verification() %}
  {% do record_deletion_results([
    {'status': 'pass', 'node': {'resource_type': 'test', 'name': 'assert_layer2_terminal_deletion'}}
  ]) %}
  {% set counts = run_query("select count(*) from " ~ deletion_evidence_relation('execution_events') ~ " where status = 'VERIFIED'") %}
  {% if counts.rows[0][0] != 0 %}
    {{ exceptions.raise_compiler_error('Partial tests incorrectly verified the deletion plan') }}
  {% endif %}
  {% do record_deletion_results([
    {'status': 'fail', 'node': {'resource_type': 'test', 'name': 'assert_layer2_terminal_deletion'}}
  ]) %}
  {% set failures = run_query("select count(*) from " ~ deletion_evidence_relation('execution_events') ~ " where target_relation = '__workflow__' and status = 'FAILED'") %}
  {% if failures.rows[0][0] != 2 %}
    {{ exceptions.raise_compiler_error('Failed verification did not record durable failure') }}
  {% endif %}
{% endmacro %}

{% macro operations_fixture_assert_retained() %}
  {% if run_query('select count(*) from ' ~ ref('customer_deletion_requests')).rows[0][0] != 1 %}
    {{ exceptions.raise_compiler_error('Full refresh erased a retained control request') }}
  {% endif %}
{% endmacro %}
