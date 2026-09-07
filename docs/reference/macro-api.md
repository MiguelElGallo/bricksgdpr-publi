---
title: Macro API reference
icon: lucide/braces
---

# Macro API reference

This is the complete developer API for generating models across Layer1, `priva_map`, Layer2,
Layer3, and Layer3 case views. The layer-model operations emit readable SQL and schema YAML for
review and source control. The deletion generators remain the runtime enforcement API used inside
generated customer-dependent models.

For the tombstone lifecycle, terminal-ledger admission algorithm, runtime call graph, and the
complete inventory of public and internal deletion-related macros, read
[Customer deletion tombstone and macros](deletion-control.md).

These eleven public generation macros are covered:

| Macro | Use it to |
| --- | --- |
| `generate_layer_model_scaffold` | Generate one model from a specification that includes its layer |
| `generate_layer1_model` | Generate a Layer1 STAGING, QUARANTINE, or CONTROL model |
| `generate_priva_map_model` | Generate a restricted MAPPING model |
| `generate_layer2_model` | Generate a Layer2 KEYED, RESOLUTION, PUBLISHED, or CONTROL model |
| `generate_layer3_model` | Generate a DIMENSION, DATE_DIMENSION, or FACT model |
| `generate_layer3_case_model` | Generate a controlled CASE_VIEW model |
| `generate_all_layer_models` | Generate multiple specifications in order |
| `generate_customer_deletion_scaffold` | Preview the model SQL, target mapping, derived action row, and schema YAML for one model |
| `generate_customer_deletion_model` | Generate the governed SQL `select` inside a dbt model |
| `generate_customer_deletion_target_relations` | Generate the complete deletion-target relation from model mappings |
| `generate_customer_deletion_target_row` | Generate one validated target tuple, normally through the relations macro |

The generated `customer_deletion_generated_contract` data test is an output of the scaffold, not a
model-generation API. The lower-level policy macros, SQL-expression helpers, project hooks, access
control operations, schema naming override, and private macros whose names begin with `_` are also
outside this API.

## Layer-model scaffold API

The layer-model generators follow the same pattern as dbt Labs' `dbt-codegen` package: a
`dbt run-operation` call logs source code that a developer reviews, pastes into the project, and
refines. The generated SQL keeps `ref()` dependencies and explicit projections visible. It does not
replace dbt's built-in view, table, incremental, or ephemeral materializations.

This boundary follows dbt's guidance to use macros for repeated SQL while favoring readability over
maximal DRYness. See the official [Jinja and macros](https://docs.getdbt.com/docs/build/jinja-macros),
[macro properties](https://docs.getdbt.com/reference/macro-properties),
[macro arguments](https://docs.getdbt.com/reference/resource-properties/arguments), and
[`dbt-codegen`](https://github.com/dbt-labs/dbt-codegen), and
[dbt-databricks column configuration](https://docs.getdbt.com/reference/resource-configs/databricks-configs#configuring-columns)
references.

### Supported layers and kinds

| Layer operation | `model_kind` | Repository pattern | Default materialization | Default tags |
| --- | --- | --- | --- | --- |
| `generate_layer1_model` | `STAGING` | Typed and normalized source projection | `view` | `layer1` |
| `generate_layer1_model` | `QUARANTINE` | Readable rejected rows with terminal-deletion suppression | `table` | `layer1`, `quarantine`, `personal_data` |
| `generate_layer1_model` | `CONTROL` | Deletion request, authorization, or other governed control state | `table` | `deletion_control`, `personal_data_control` |
| `generate_priva_map_model` | `MAPPING` | Restricted readable values paired with domain-separated keys | `table` | `priva_map`, `personal_data` |
| `generate_layer2_model` | `KEYED` | Source projection with readable identifiers replaced by keys | `ephemeral` | `layer2`, `personal_data` |
| `generate_layer2_model` | `RESOLUTION` | Quality classification and optional deletion policy | `ephemeral` | `layer2`, `personal_data` |
| `generate_layer2_model` | `PUBLISHED` | Accepted protected projection | `table` | `layer2`, `personal_data` |
| `generate_layer2_model` | `CONTROL` | Deletion plan or suppression-control state | `table` | `deletion_control`, `personal_data_control` |
| `generate_layer3_model` | `DIMENSION` | Entity dimension with an optional erased-subject member | `table` | `layer3_dimensions` |
| `generate_layer3_model` | `DATE_DIMENSION` | Inclusive Databricks calendar generated from project variables | `table` | `layer3_dimensions`, `non_personal_data` |
| `generate_layer3_model` | `FACT` | Entity-grained fact with terminal-deletion enforcement | `table` | `layer3_facts`, `personal_data` |
| `generate_layer3_case_model` | `CASE_VIEW` | Controlled readable projection with access and erased-row filters | `view` | `case_views` |

`KEYED` and `RESOLUTION` must remain ephemeral. `CASE_VIEW` must remain a view. Other kinds may
override `materialized` with a supported built-in materialization; `incremental` also requires an
incremental configuration mapping. Column-level Databricks tags or masks require `table` or
`incremental`. A model registered as a deletion target must be a physical table/incremental model,
except CASE_VIEW, which is registered as a view.

Incremental configuration defaults to `strategy: merge` and `on_schema_change: fail`; `unique_key`
has no default and must name one or more visible output columns.

### Signatures

```jinja
generate_layer_model_scaffold(spec)
generate_layer1_model(spec)
generate_priva_map_model(spec)
generate_layer2_model(spec)
generate_layer3_model(spec)
generate_layer3_case_model(spec)
generate_all_layer_models(specs)
```

The generic operation requires `spec.layer`. A layer-specific operation supplies the layer and
rejects a conflicting `spec.layer`. `generate_all_layer_models` accepts a nonempty ordered list of
specifications, each with its own layer.

### Common specification

| Key | Required | Contract |
| --- | --- | --- |
| `layer` | Generic and batch operations | `layer1`, `priva_map`, `layer2`, `layer3`, or `layer3_case` |
| `model_kind` | Yes | One kind allowed by the selected layer |
| `model_name` | Yes | Simple SQL identifier |
| `description` | Yes | Nonempty grain-and-purpose description used in schema YAML |
| `primary_key` | Except DATE_DIMENSION | One identifier or a nonempty list; every item must be a visible output column |
| `columns` | Except DATE_DIMENSION | Ordered, nonempty visible output-column specifications |
| `helper_columns` | No | Source-only columns needed by a deletion policy, such as `deletion_mode` or `is_erased_customer`; omitted from final output and YAML |
| `source_model` | One source form | Simple dbt model name emitted through `ref()` |
| `source_cte` | One source form | Name of an entry in `ctes`; use instead of `source_model` for bespoke control logic |
| `source_alias` | No | Simple source alias; default `source_rows` |
| `ctes` | No | Ordered `{name, sql}` mappings emitted before the generated projection |
| `joins` | No | Ordered model or CTE joins |
| `where` | No | Ordered nonempty SQL predicates combined with `and` |
| `tags` | No | Additional tags appended to the kind defaults |
| `materialized` | No | `view`, `table`, `incremental`, or `ephemeral`, subject to kind restrictions |
| `incremental` | For incremental | `unique_key` drawn from visible output columns, plus optional `strategy` and `on_schema_change` |
| `databricks_tags` | No | String-to-string mapping emitted in the model config |
| `deletion` | QUARANTINE, MAPPING, FACT, CASE_VIEW; optional on other non-date kinds | Generated terminal-deletion contract; kinds without a shared deletion type require explicit `model_type` |
| `erased_member` | DIMENSION when required | Expression for every output column in the synthetic erased-subject row |
| `start_var`, `end_var` | DATE_DIMENSION only | Project variable names; defaults `date_dimension_start` and `date_dimension_end` |

Exactly one of `source_model` or `source_cte` is required outside DATE_DIMENSION. Raw `ctes.sql`,
column expressions, join conditions, and predicates are emitted as source code, not executed by the
operation. They exist for model-specific business logic that cannot safely be generalized.

DATE_DIMENSION owns its columns, primary key, source, and calendar SQL. It rejects those generic
fields plus deletion and erased-member declarations; use only its model metadata, tags,
materialization/incremental settings, and `start_var`/`end_var` variable names.

### DATE_DIMENSION fixed contract

DATE_DIMENSION is source-free. It expands an inclusive Databricks `sequence()` between the project
variables named by `start_var` and `end_var`, which default to `date_dimension_start` and
`date_dimension_end`. The generated primary key is `date_key`; developers do not provide columns.

The fixed ordered output is:

```text
date_key
date_day
calendar_year
calendar_quarter
month_number
month_name
day_of_month
day_of_week
day_name
iso_week_number
is_weekend
```

`date_key` and `date_day` receive `not_null` and `unique`; the remaining columns receive
`not_null`. The schema contract uses Databricks types `int`, `date`, `string`, and `boolean`.

### Column specification

Each visible output column has this shape:

```yaml
- name: customer_key
  key:
    expression: customer_ssn
    domain: customer.ssn
    kind: ssn
  data_type: string
  description: Stable pseudonymous customer key used for governed joins.
  tests: [not_null]
```

| Key | Required | Contract |
| --- | --- | --- |
| `name` | Yes | Unique simple identifier |
| `expression` | One expression form | Nonempty SQL emitted as `<expression> as <name>` |
| `key` | One expression form | `expression`, `domain`, and optional `kind`; emits `personal_data_key()` |
| `data_type` | Yes | dbt/Databricks contract type written to schema YAML |
| `description` | Yes | Nonempty semantic description |
| `tests` | No | Simple generic test names appended to generated YAML |
| `databricks_tags` | No | String-to-string Unity Catalog column tags; requires table or incremental materialization |
| `column_mask` | MAPPING readable columns | `function` plus optional `using_columns`; emitted as dbt-databricks column configuration |

When both `expression` and `key` are absent, the generator selects
`<source_alias>.<name>`. `expression` and `key` are mutually exclusive. Primary-key columns receive
`not_null`; a single-column key also receives `unique`. Composite grains still require an explicit
model-level uniqueness test.

Generated schema YAML sets `contract.enforced: true` for view, table, and incremental models. It
sets enforcement to `false` for ephemeral models, which dbt inlines rather than materializing as a
contracted relation.

Helper columns accept `name` plus the same optional `expression` or `key`, but do not require
documentation metadata because they are not part of the model contract. They are allowed only when
`deletion` is present and cannot duplicate a visible column.

`key.kind` is strict and case-insensitive: `text`, `ssn`, `phone`, or `date`. Unknown values fail
generation instead of silently producing a deletion key with a different canonical form.

Every readable Personal Data column in a MAPPING scaffold must carry its Unity Catalog
`databricks_tags` and a `column_mask`. For example:

```yaml
- name: customer_ssn_value
  expression: source_rows.customer_ssn
  data_type: string
  description: Readable SSN available only through the restricted mapping boundary.
  databricks_tags:
    personal_data_category: NATIONAL_IDENTIFIER
    personal_data_state: RAW
  column_mask:
    function: "{{ var('project_catalog', env_var('DBT_PROJECT_CATALOG', 'bricksgdpr')) }}.priva_internal.mask_priva_map_value"
    using_columns: customer_key
```

The generator emits these properties into schema YAML. It does not infer masks from names or
expressions; omitting a required mask is a developer error that must be caught during review and by
the mapping mask/tag acceptance tests.

### Join and CTE specifications

```yaml
ctes:
  - name: classified_orders
    sql: |
      select ... from {{ ref('int_orders_keyed') }}
joins:
  - model: fa_pd_customer
    alias: mapped
    type: inner
    "on": orders.customer_key = mapped.customer_key
```

A join accepts exactly one of `model` or `cte`, a unique simple `alias`, and `inner`, `left`, or
`cross` type. Non-cross joins require `on`. Quote the YAML key as `"on"`; YAML 1.1 can otherwise
parse it as Boolean `true`, which the generator also normalizes for compatibility. A CTE accepts a
unique simple `name` and nonempty SQL body. `source_cte` and joined CTEs must name declared entries.
CTE names are unique among CTEs, and relation aliases are unique among source/join aliases. Neither
namespace may use the reserved generated names `generated_rows`, `governed_rows`, or
`erased_subject_member`.
This escape hatch is how bespoke authorization and terminal-ledger state machines remain explicit
instead of being mislabeled as generic transformations.

### Deletion specification

An optional `spec.deletion` mapping delegates the generated projection to
`generate_customer_deletion_model()`. Fixed QUARANTINE, MAPPING, DIMENSION, FACT, and CASE_VIEW
kinds must use their matching deletion type. FACT specifications declare replacement keys and an
erased flag; CASE_VIEW specifications combine access control with erased-row exclusion. Setting
`register_target: true` logs the mapping and derived action row but does not edit the registry.

The accepted fields, defaults, mode-specific behavior, and compiler failures are canonical in
[Customer deletion tombstone and macros](deletion-control.md#generate-a-complete-layer-native-model).

### Example: generate a Layer2 keyed model

```bash
uv run dbt run-operation generate_layer2_model --args '
  spec:
    model_kind: KEYED
    model_name: int_orders_keyed
    description: Pseudonymized orders at one row per source order.
    primary_key: order_id
    source_model: stg_orders
    columns:
      - name: order_id
        data_type: string
        description: Stable source order identifier.
      - name: customer_key
        key: {expression: customer_ssn, domain: customer.ssn, kind: ssn}
        data_type: string
        description: Stable pseudonymous customer key used for governed joins.
      - name: amount
        data_type: decimal(18,2)
        description: Typed order amount.
'
```

The operation logs `MODEL SQL` and `SCHEMA YAML`. When `deletion.register_target=true`, it also
logs `TARGET REGISTRY ENTRY` and `DERIVED TARGET ROW`. It returns a short completion message and
does not write files, execute the emitted model, or mutate the warehouse.

### Batch generation

```bash
uv run dbt run-operation generate_all_layer_models --args '{specs: [...]}'
```

Specifications are validated and logged in order. The batch stops at the first invalid contract so
partially valid source is not mistaken for a complete generated integration.

**Implementation and argument metadata:** `macros/layer_model_generators.sql` and
`macros/layer_model_generators.yml`. Compile-contract coverage in
`tests/assert_layer_model_generators.sql` exercises all twelve supported layer-kind combinations,
including both CONTROL layers, generated mapping masks/tags, a fresh FACT policy, a governed
dimension plus erased member, and YAML Boolean-`on` compatibility.

## Customer-deletion generator summary

The detailed tombstone page is the canonical deletion-specific API. It owns the signatures,
defaults, compiler failures, execution paths, examples, generated-test contract, and exact
17-target registry so those contracts do not drift across two reference pages.

| Macro | Generated artifact |
| --- | --- |
| `generate_customer_deletion_scaffold` | Logs ready-to-paste model SQL, registry mapping, derived target tuple, and schema YAML |
| `generate_customer_deletion_model` | Returns the governed SQL projection for FACT, delete-style table, or CASE_VIEW behavior |
| `generate_customer_deletion_target_relations` | Returns the complete five-column target-registry relation |
| `generate_customer_deletion_target_row` | Returns one target tuple with actions derived from model type |
| `customer_deletion_generated_contract` | Fails a generated model on grain, erased-member, case-view, or surviving-terminal-key violations |

Use [Customer deletion tombstone and macros](deletion-control.md#deletion-specific-macro-api) for
all deletion-specific arguments and examples. The supported model types are `FACT`, `DIMENSION`,
`MAPPING`, `SERVICE`, `QUARANTINE`, `IDENTITY`, `DEPENDENT`, and `CASE_VIEW`; developers
declare the type and never hand-write FULL or SPECIAL action strings.

## Add and validate generated artifacts

### Layer-model scaffold

The seven layer operations log complete `MODEL SQL` and `SCHEMA YAML` blocks. Save both in the
appropriate model directory. A target mapping and derived row are logged only when
`deletion.register_target: true`; append that mapping to `customer_deletion_target_relations()` and
never copy or maintain action strings manually.

Layer scaffolds emit column tests and contract metadata, but they do not add the
`customer_deletion_generated_contract` generic test. Add model-specific tests for business rules,
mapping masks/tags, and deletion outcomes that cannot be inferred from the specification.

```bash
uv run dbt compile --select fct_order
uv run dbt build --select +fct_order
uv run dbt test --select assert_layer_model_generators
uv run dbt test --select tag:deletion_control
```

### Deletion-contract scaffold

`generate_customer_deletion_scaffold` logs a `generate_customer_deletion_model()` call, target
mapping, derived target row, and schema fragment containing
`customer_deletion_generated_contract`. Save the call in the handwritten model, merge the schema
fragment into its YAML, and append the target mapping.

```bash
uv run dbt compile --select fct_order
uv run dbt build --select +fct_order
uv run dbt test --select test_name:customer_deletion_generated_contract
uv run dbt test --select assert_customer_deletion_generators
uv run dbt test --select tag:deletion_control
```

When either workflow adds a governed target, update fixed target counts and walkthrough fixtures.
Generated contracts verify declared grain and deletion mechanics; they cannot infer whether
measures, dates, joins, authorization scope, or other model-specific business rules are correct.

**Implementation and argument metadata:** `macros/customer_deletion_generators.sql` and
`macros/customer_deletion_generators.yml`.

See [Deletion operations and recovery](deletion-operations.md) for durable control archives, execution states,
isolated private validation, and recovery rehearsal.

## Operational macros

The [operations reference](deletion-operations.md) owns the evidence schema and recovery contract.
`bootstrap_project_catalog()` creates analytical/evidence catalogs; `begin_deletion_execution()`
records pending targets; `restore_deletion_control(model_name)` restores only a missing durable
control from reviewed archived evidence. `record_deletion_failure()` records a workflow failure;
the bundle-only `record_deletion_failure_and_raise()` then fails deliberately so the parent job
retains a failed status and notification eligibility. Archive, guard, digest, and results macros
are internal hooks. Do not call `append_deletion_event` manually to claim verification.

The `on-run-end` hook in `dbt_project.yml` assigns `ref('int_customer_deletion_plan')` to a Jinja
variable unconditionally before calling `record_deletion_results`. This makes the dependency
visible during parsing without emitting a standalone SQL comment or querying the plan when
execution tracking is disabled.
