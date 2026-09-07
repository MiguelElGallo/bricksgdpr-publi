{# Evidence lives outside dbt-managed analytical relations. No macro drops or replaces it. #}
{% macro deletion_evidence_relation(name) -%}
  {% set project = var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) %}
  {% set catalog = var('evidence_catalog', env_var('DBT_EVIDENCE_CATALOG', project ~ '_evidence')) %}
  {% if catalog | lower == project | lower %}
    {{ exceptions.raise_compiler_error('Evidence catalog must differ from project catalog') }}
  {% endif %}
  {% if name not in ['control_history', 'execution_events'] %}
    {{ exceptions.raise_compiler_error('Unknown evidence relation') }}
  {% endif %}
  {{ return(adapter.quote(catalog) ~ '.`deletion_control`.' ~ adapter.quote(name)) }}
{%- endmacro %}

{% macro deletion_execution_id() -%}
  {% set value = var('deletion_execution_id', invocation_id) | string %}
  {% if not modules.re.fullmatch('[A-Za-z0-9_-]{1,128}', value) %}
    {{ exceptions.raise_compiler_error('Invalid deletion_execution_id') }}
  {% endif %}
  {{ return(value) }}
{%- endmacro %}

{% macro bootstrap_deletion_evidence() %}
  {% if execute %}
    {% set history = deletion_evidence_relation('control_history') %}
    {% set events = deletion_evidence_relation('execution_events') %}
    {% set schema = history.rsplit('.', 1)[0] %}
    {% set catalog = schema.rsplit('.', 1)[0] %}
    {% do run_query('create catalog if not exists ' ~ catalog) %}
    {% do run_query('create schema if not exists ' ~ schema) %}
    {% do run_query('create table if not exists ' ~ history ~ ' (
      source_relation string not null, payload_hash string not null, payload string not null,
      archived_at timestamp not null, invocation_id string not null
    ) using delta tblproperties (\'delta.appendOnly\'=\'true\')') %}
    {% do run_query('create table if not exists ' ~ events ~ ' (
      execution_id string not null, target_relation string not null,
      plan_digest string not null, status string not null,
      recorded_at timestamp not null, invocation_id string not null
    ) using delta tblproperties (\'delta.appendOnly\'=\'true\')') %}
    {% for relation in [history, events] %}
      {% set properties = run_query('show tblproperties ' ~ relation ~ " ('delta.appendOnly')") %}
      {% if properties.rows[0][1] | lower != 'true' %}
        {{ exceptions.raise_compiler_error('Evidence table must have delta.appendOnly=true') }}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}

{% macro archive_deletion_control(relation, immutable_keys=[]) %}
  {% set history = deletion_evidence_relation('control_history') %}
  {% if execute and immutable_keys | length > 0 %}
    {% set conflicts %}
      select count(*) from {{ relation }} as source
      inner join {{ history }} as archived
        on archived.source_relation = '{{ relation | string | replace("'", "''") }}'
        {% for key in immutable_keys %}
          and get_json_object(archived.payload, '$.{{ key }}') = cast(source.{{ adapter.quote(key) }} as string)
        {% endfor %}
      where archived.payload_hash <> sha2(to_json(struct(source.*)), 256)
    {% endset %}
    {% if run_query(conflicts).rows[0][0] > 0 %}
      {{ exceptions.raise_compiler_error('A recorded decision revision changed. Submit a new revision instead.') }}
    {% endif %}
  {% endif %}
  insert into {{ history }}
  select '{{ relation | string | replace("'", "''") }}', incoming.payload_hash,
         incoming.payload, current_timestamp(), '{{ invocation_id }}'
  from (
    select distinct sha2(to_json(struct(source.*)), 256) as payload_hash,
           to_json(struct(source.*)) as payload from {{ relation }} as source
  ) as incoming
  where not exists (
    select 1 from {{ history }} as existing
    where existing.source_relation = '{{ relation | string | replace("'", "''") }}'
      and existing.payload_hash = incoming.payload_hash
  )
{% endmacro %}

{% macro guard_deletion_control(relation) %}
  {% if execute %}
    {% set existing = adapter.get_relation(relation.database, relation.schema, relation.identifier) %}
    {% if existing is none %}
      {% set prior = run_query('select count(*) from ' ~ deletion_evidence_relation('control_history')
        ~ " where source_relation = '" ~ (relation | string | replace("'", "''")) ~ "'") %}
      {% if prior.rows[0][0] > 0 %}
        {{ exceptions.raise_compiler_error(
          'Control relation missing but durable evidence exists. Stop and restore reviewed evidence; '
          ~ 'do not rebuild deletion controls from current source fixtures.'
        ) }}
      {% endif %}
    {% else %}
      {% set keys = {
        'customer_deletion_requests': ['deletion_request_id'],
        'int_customer_deletion_plan': ['decision_revision_id', 'customer_key', 'target_layer',
          'target_relation', 'deletion_mode', 'deletion_policy_version'],
        'int_terminal_deleted_customer_keys': ['customer_key']
      } %}
      {% set missing %}
        select count(*) from {{ deletion_evidence_relation('control_history') }} as archived
        where archived.source_relation = '{{ relation | string | replace("'", "''") }}'
          and not exists (
            select 1 from {{ relation }} as current
            where {% for key in keys[relation.identifier] %}
              get_json_object(archived.payload, '$.{{ key }}') = cast(current.{{ adapter.quote(key) }} as string)
              {% if not loop.last %}and{% endif %}
            {% endfor %}
            {% if relation.identifier == 'int_terminal_deleted_customer_keys' %}
              and (get_json_object(archived.payload, '$.deletion_mode') <> 'FULL_GOVERNED_OUTPUT_DELETION'
                or current.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION')
            {% endif %}
          )
      {% endset %}
      {% if run_query(missing).rows[0][0] > 0 %}
        {{ exceptions.raise_compiler_error('Durable control keys are missing or downgraded. Stop for audited recovery.') }}
      {% endif %}
    {% endif %}
  {% endif %}
  select 1
{% endmacro %}

{% macro deletion_plan_digest_sql() %}
  select plan.target_relation,
    sha2(concat_ws('', sort_array(collect_list(sha2(to_json(struct(plan.*)), 256)))), 256)
      as plan_digest
  from {{ ref('int_customer_deletion_plan') }} as plan
  group by plan.target_relation
{% endmacro %}

{% macro append_deletion_event(target_name, status) %}
  {% if status not in ['PENDING', 'COMPLETED', 'FAILED', 'VERIFIED'] %}
    {{ exceptions.raise_compiler_error('Invalid deletion execution status') }}
  {% endif %}
  {% set sql %}
    insert into {{ deletion_evidence_relation('execution_events') }}
    select '{{ deletion_execution_id() }}', target_relation, plan_digest,
      '{{ status }}', current_timestamp(), '{{ invocation_id }}'
    from ({{ deletion_plan_digest_sql() }})
    {% if target_name is not none %}
      where target_relation = '{{ target_name | replace("'", "''") }}'
    {% endif %}
  {% endset %}
  {% do run_query(sql) %}
{% endmacro %}

{% macro begin_deletion_execution() %}
  {% if execute %}
    {% do append_deletion_event(none, 'PENDING') %}
  {% endif %}
{% endmacro %}

{% macro record_deletion_results(results) %}
  {% if execute and var('track_deletion_execution', false) %}
    {% set required = [
      'assert_customer_deletion_control', 'assert_unconfirmed_deletion_not_authorized',
      'assert_layer2_terminal_deletion', 'assert_layer3_terminal_deletion',
      'assert_case_views_terminal_deletion', 'assert_erased_member_invariants',
      'assert_layer2_invoice_partition', 'assert_layer2_event_partition',
      'assert_layer2_service_partition', 'assert_access_relation_grants',
      'assert_access_parent_privileges', 'assert_access_no_ambient_grants',
      'assert_deletion_evidence_access'
    ] %}
    {% set target_rows = run_query('select distinct target_relation from (' ~ deletion_plan_digest_sql() ~ ')') %}
    {% set targets = target_rows.columns[0].values() | list %}
    {% set passed = [] %}
    {% set state = namespace(failed=false) %}
    {% for result in results %}
      {% if result.status | string not in ['success', 'pass'] %}
        {% set state.failed = true %}
      {% endif %}
      {% if result.node.resource_type == 'model' and result.node.name in targets %}
        {% do append_deletion_event(result.node.name,
          'COMPLETED' if result.status | string == 'success' else ('PENDING' if result.status | string == 'skipped' else 'FAILED')) %}
      {% elif result.node.resource_type == 'test' and result.status | string == 'pass' %}
        {% do passed.append(result.node.name) %}
      {% endif %}
    {% endfor %}
    {% if state.failed %}{% do record_deletion_failure() %}{% endif %}
    {% set missing = [] %}
    {% for name in required %}
      {% if name not in passed %}{% do missing.append(name) %}{% endif %}
    {% endfor %}
    {% if not state.failed and missing | length == 0 %}
      {# Verification is recorded only for targets completed under this execution and plan. #}
      {% set incomplete %}
        select count(*) from ({{ deletion_plan_digest_sql() }}) as plan
        where not exists (
          select 1 from (
            select *, row_number() over (
              partition by target_relation order by recorded_at desc, invocation_id desc
            ) as event_rank
            from {{ deletion_evidence_relation('execution_events') }}
            where execution_id = '{{ deletion_execution_id() }}'
          ) as event
          where event.target_relation = plan.target_relation
            and event.plan_digest = plan.plan_digest
            and event.status in ('COMPLETED', 'VERIFIED') and event.event_rank = 1
        )
      {% endset %}
      {% if run_query(incomplete).rows[0][0] != 0 %}
        {{ exceptions.raise_compiler_error('Cannot verify: not all current plan targets completed in this execution') }}
      {% endif %}
      {% do append_deletion_event(none, 'VERIFIED') %}
    {% endif %}
  {% endif %}
{% endmacro %}

{% macro restore_deletion_control(model_name) %}
  {# Explicit recovery only: reconstruct a missing table from typed archived evidence. #}
  {% set allowed = {
    'customer_deletion_requests': ['deletion_request_id'],
    'int_customer_deletion_plan': ['decision_revision_id', 'customer_key', 'target_layer',
      'target_relation', 'deletion_mode', 'deletion_policy_version'],
    'int_terminal_deleted_customer_keys': ['customer_key']
  } %}
  {% if model_name not in allowed %}
    {{ exceptions.raise_compiler_error('Only durable request, plan and terminal controls can be restored') }}
  {% endif %}
  {% if execute %}
    {% set node = graph.nodes['model.bricksgdpr.' ~ model_name] %}
    {% set relation = ref(model_name) %}
    {% if adapter.get_relation(relation.database, relation.schema, relation.identifier) is not none %}
      {{ exceptions.raise_compiler_error('Recovery refuses to overwrite an existing relation') }}
    {% endif %}
    {% set fields = [] %}
    {% for name, column in node.columns.items() %}
      {% do fields.append(adapter.quote(name) ~ ' ' ~ column.data_type) %}
    {% endfor %}
    {% set prior = run_query('select count(*) from ' ~ deletion_evidence_relation('control_history')
      ~ " where source_relation = '" ~ (relation | string | replace("'", "''")) ~ "'") %}
    {% if prior.rows[0][0] == 0 %}
      {{ exceptions.raise_compiler_error('Recovery requires existing archived evidence') }}
    {% endif %}
    {% set sql %}
      create table {{ relation }} using delta as
      with decoded as (
        select from_json(payload, '{{ fields | join(', ') }}') as record,
          archived_at, invocation_id, payload_hash
        from {{ deletion_evidence_relation('control_history') }}
        where source_relation = '{{ relation | string | replace("'", "''") }}'
      ), ranked as (
        select record.*, row_number() over (
          partition by {% for key in allowed[model_name] %}record.{{ adapter.quote(key) }}{% if not loop.last %}, {% endif %}{% endfor %}
          order by
          {% if model_name == 'int_terminal_deleted_customer_keys' %}
            case record.deletion_mode when 'FULL_GOVERNED_OUTPUT_DELETION' then 0 else 1 end,
          {% endif %}
            archived_at desc, invocation_id desc, payload_hash desc
        ) as recovery_rank
        from decoded
      )
      select {% for name in node.columns %}{{ adapter.quote(name) }}{% if not loop.last %}, {% endif %}{% endfor %}
      from ranked where recovery_rank = 1
    {% endset %}
    {% do run_query(sql) %}
    {% do adapter.cache_added(relation.incorporate(type='table')) %}
    {% do log('Restored control evidence. Rebuild affected descendants and reapply access controls before verification.', info=true) %}
  {% endif %}
{% endmacro %}

{% macro record_deletion_failure() %}
  {% if execute %}
    {% set sql %}
      insert into {{ deletion_evidence_relation('execution_events') }}
      values ('{{ deletion_execution_id() }}', '__workflow__', '{{ '0' * 64 }}',
              'FAILED', current_timestamp(), '{{ invocation_id }}')
    {% endset %}
    {% do run_query(sql) %}
  {% endif %}
{% endmacro %}

{% macro apply_deletion_evidence_access() %}
  {% if execute %}
    {% set history = deletion_evidence_relation('control_history') %}
    {% set events = deletion_evidence_relation('execution_events') %}
    {% set schema = history.rsplit('.', 1)[0] %}
    {% set catalog = schema.rsplit('.', 1)[0] %}
    {# Consumers must not inherit access to raw control evidence. The owner retains access. #}
    {% for principal in ['privacy_admins', 'restricted_users', 'case_users'] %}
      {% do run_query('revoke all privileges on catalog ' ~ catalog
          ~ ' from ' ~ adapter.quote(principal)) %}
      {% do run_query('revoke all privileges on schema ' ~ schema
          ~ ' from ' ~ adapter.quote(principal)) %}
      {% for relation in [history, events] %}
        {% do run_query('revoke all privileges on table ' ~ relation ~ ' from ' ~ adapter.quote(principal)) %}
      {% endfor %}
    {% endfor %}
  {% endif %}
{% endmacro %}

{% macro record_deletion_failure_and_raise() %}
  {% do record_deletion_failure() %}
  {{ exceptions.raise_compiler_error('Workflow failed; durable failure recording was attempted') }}
{% endmacro %}
