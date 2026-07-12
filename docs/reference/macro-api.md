---
title: Macro API reference
icon: lucide/braces
---

# Macro API reference

This is the complete developer API for generating models across Layer1, `priva_map`, Layer2,
Layer3, and Layer3 case views. The layer-model operations emit readable SQL and schema YAML for
review and source control. The deletion generators remain the runtime enforcement API used inside
generated customer-dependent models.

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
    function: "{{ env_var('DBT_PROJECT_CATALOG', 'bricksgdpr') }}.priva_internal.mask_priva_map_value"
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

| Key | Required | Default | Contract |
| --- | --- | --- | --- |
| `model_type` | Conditional | Current kind | Must match QUARANTINE, MAPPING, DIMENSION, FACT, or CASE_VIEW kinds; STAGING, KEYED, RESOLUTION, PUBLISHED, and either CONTROL kind require an explicit shared type when deletion is supplied |
| `customer_key_column` | No | `customer_key` | Visible customer-key column; CASE_VIEW may instead use an erased helper flag |
| `customer_key_expression` | No | Direct column | Advanced SQL expression for ledger matching |
| `customer_key_domain` | No | None | Generates `personal_data_key(source_rows.<customer_key_column>, domain, kind)` for readable input |
| `customer_key_kind` | No | `text` | Exactly `text`, `ssn`, `phone`, or `date`, case-insensitive |
| `special_replacement_columns` | FACT | None | FACT keys replaced with the erased member |
| `erased_flag_column` | FACT or flag-based CASE_VIEW | None | Generated FACT flag or CASE_VIEW helper flag |
| `source_is_mode_annotated` | No | `false` | Reuses a helper mode column |
| `source_is_policy_applied` | No | `false` | Validating downstream FACT projection |
| `deletion_mode_column` | No | `deletion_mode` | Existing mode-column name |
| `additional_predicate` | CASE_VIEW | `case_access_predicate()` | Authorization SQL applied before erased-row exclusion |
| `register_target` | No | `false` | Also logs the declarative target mapping and derived target row; requires table/incremental except CASE_VIEW |

`customer_key_expression` and `customer_key_domain` are mutually exclusive. Generated deletion
calls retain all validation documented later for `generate_customer_deletion_model`.

For a fresh FACT policy, declare `erased_flag_column` as a visible Boolean column. The generator
does not select that field from the source; the deletion policy creates it, and the generated schema
contract documents it. With `source_is_policy_applied=true`, the flag must already exist in the
source and is projected unchanged. For DIMENSION with both `deletion` and `erased_member`, policy
filtering produces `governed_rows` first and the synthetic member is unioned afterward.

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

## Shared model types

All four deletion generators use the same case-insensitive `model_type` values and derive deletion behavior from
the type. Developers never pass FULL or SPECIAL action strings.

| `model_type` | SPECIAL output behavior | FULL output behavior | Target kind | Derived SPECIAL action |
| --- | --- | --- | --- | --- |
| `FACT` | Replace every declared key with `erased_member_key`; add the erased flag | Remove the row | `TABLE` | `REASSIGN_TO_ERASED_MEMBER` |
| `DIMENSION` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `MAPPING` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `SERVICE` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `QUARANTINE` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `IDENTITY` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `DEPENDENT` | Remove the row | Remove the row | `TABLE` | `DELETE_CURRENT_ROWS` |
| `CASE_VIEW` | Exclude the erased row | Relies on upstream removal; does not join the ledger | `VIEW` | `EXCLUDE_ERASED_ROWS` |

The FULL target action is `DELETE_CURRENT_ROWS` for every table type and
`EXCLUDE_DELETED_ROWS` for `CASE_VIEW`.

## `generate_customer_deletion_scaffold`

Use this as the deletion-contract entry point for an already handwritten or migrated model. For a
complete new layer-native model, start with the applicable layer generator. This macro validates
the deletion declaration and prints its source-controlled artifacts without writing files or
changing warehouse data.

### Signature

```jinja
generate_customer_deletion_scaffold(
    model_name,
    model_type,
    target_layer,
    source_model,
    primary_key,
    output_columns,
    customer_key_column='customer_key',
    customer_key_expression=none,
    customer_key_domain=none,
    customer_key_kind='text',
    special_replacement_columns=none,
    erased_flag_column=none,
    source_is_policy_applied=false,
    target_kind=none
)
```

### Arguments

| Argument | Required | Default | Contract |
| --- | --- | --- | --- |
| `model_name` | Yes | — | Simple SQL identifier used in the emitted model call, target mapping, schema YAML, and validation messages |
| `model_type` | Yes | — | One of the shared model types above; matching is case-insensitive |
| `target_layer` | Yes | — | Simple SQL identifier stored in the target registry, such as `layer1`, `layer2`, or `layer3` |
| `source_model` | Yes | — | Simple SQL identifier emitted as `ref('<source_model>')` |
| `primary_key` | Yes | — | One identifier or a nonempty list of identifiers; every item must occur in `output_columns` |
| `output_columns` | Yes | — | Nonempty, ordered, duplicate-free list of simple SQL identifiers |
| `customer_key_column` | No | `customer_key` | Simple identifier used for direct ledger matching and in the generated data-test contract |
| `customer_key_expression` | No | `none` | Nonempty SQL used for advanced ledger matching; must contain `source_rows.` and cannot be combined with `customer_key_domain` |
| `customer_key_domain` | No | `none` | Nonempty domain passed to `personal_data_key` when the source contains raw Personal Data; cannot be combined with `customer_key_expression` |
| `customer_key_kind` | No | `text` | Strict canonicalization kind: `text`, `ssn`, `phone`, or `date`, case-insensitive |
| `special_replacement_columns` | FACT only | `none` | Nonempty list of output keys replaced with `erased_member_key`; it must include `customer_key_column` |
| `erased_flag_column` | No | `is_erased_customer` for FACT; otherwise `none` | Simple identifier for a FACT output flag or CASE_VIEW input flag; an already-policy-applied FACT must already include it in `output_columns` |
| `source_is_policy_applied` | No | `false` | FACT-only mode for an upstream relation that already contains erased keys and the erased flag |
| `target_kind` | No | `VIEW` for CASE_VIEW; otherwise `TABLE` | Explicit `TABLE` or `VIEW`; it must agree with `model_type` |

### Invocation

Pass YAML arguments through `dbt run-operation`:

```bash
uv run dbt run-operation generate_customer_deletion_scaffold --args '
  model_name: fct_order
  model_type: FACT
  target_layer: layer3
  source_model: int_orders_classified
  primary_key: order_id
  output_columns:
    - order_id
    - customer_key
    - service_key
    - amount
  special_replacement_columns:
    - customer_key
    - service_key
'
```

The operation logs four sections:

1. `MODEL SQL`: a complete `generate_customer_deletion_model` call.
2. `TARGET REGISTRY ENTRY`: a mapping for the list passed to
   `generate_customer_deletion_target_relations`.
3. `DERIVED TARGET ROW`: the exact five-column tuple produced from the model type.
4. `SCHEMA YAML`: the model description, primary-key tests, generated deletion-contract test, and
   FACT erased-flag metadata.

It returns `Generated scaffold for <model_name>` after logging those sections. Copy the generated
artifacts into the appropriate model, target registry, and model YAML files; the operation itself is
preview-only.

### Raw Personal Data input

Prefer `customer_key_domain` and `customer_key_kind` when the source column contains a readable
value rather than an existing pseudonymous key:

```bash
uv run dbt run-operation generate_customer_deletion_scaffold --args '
  model_name: quarantine_orders
  model_type: QUARANTINE
  target_layer: layer1
  source_model: stg_orders
  primary_key: order_id
  output_columns: [order_id, customer_ssn, quarantine_reason]
  customer_key_column: customer_ssn
  customer_key_domain: customer.ssn
  customer_key_kind: ssn
'
```

The emitted model matches the ledger with
`personal_data_key('source_rows.customer_ssn', 'customer.ssn', 'ssn')`. The emitted test calculates
the equivalent key against `generated_model.customer_ssn`; it never compares the readable value
directly with a pseudonymous ledger key.

An unknown kind fails during scaffold generation. This prevents a typo from producing a key that
cannot match the confirmed terminal ledger.

For an expression the scaffold cannot derive, pass `customer_key_expression` with the required
`source_rows.` alias. The scaffold rewrites that alias to `generated_model.` in the emitted test.

### Scaffold limits

The scaffold intentionally exposes the supported common path. It does not accept
`source_is_mode_annotated`, `deletion_relation`, `deletion_mode_column`, or an arbitrary
`additional_predicate`. Use the emitted model call as the starting point and set those advanced
arguments directly on `generate_customer_deletion_model` when their contracts below apply.
For CASE_VIEW scaffolds, `customer_key_column` must remain in `output_columns` so the generated
contract can verify erased-member exclusion; use the direct model macro only when a deliberately
hidden key is covered by a separate model-specific test.

## `generate_customer_deletion_model`

Use this macro as the complete contents of a customer-dependent model SQL file. It emits an
explicit projection and derives its ledger join, deletion filters, erased-member replacements, and
case-view exclusion from the declared contract.

### Signature

```jinja
generate_customer_deletion_model(
    model_name,
    model_type,
    source_relation,
    primary_key,
    output_columns,
    customer_key_column='customer_key',
    customer_key_expression=none,
    special_replacement_columns=none,
    erased_flag_column='is_erased_customer',
    deletion_relation=none,
    source_is_mode_annotated=false,
    source_is_policy_applied=false,
    deletion_mode_column='deletion_mode',
    additional_predicate=none
)
```

### Arguments

| Argument | Required | Default | Contract |
| --- | --- | --- | --- |
| `model_name` | Yes | — | Simple SQL identifier used for compile-time validation messages |
| `model_type` | Yes | — | One of the shared model types; controls all generated deletion behavior |
| `source_relation` | Yes | — | A dbt relation, `ref()`, or SQL/CTE expression containing business-ready rows |
| `primary_key` | Yes | — | One identifier or a nonempty list; every item must occur in `output_columns`; this declaration is compile validation and does not add a SQL constraint |
| `output_columns` | Yes | — | Nonempty, ordered, duplicate-free list of simple identifiers; no `*` projection |
| `customer_key_column` | No | `customer_key` | Source/output customer key used when no expression is supplied; may be `none` only when another permitted matching or exclusion input is present |
| `customer_key_expression` | No | `none` | Nonempty SQL expression used instead of `source_rows.<customer_key_column>` while attaching the ledger |
| `special_replacement_columns` | FACT only | `none` | Nonempty list of output columns replaced with `erased_member_key`; must include `customer_key_column` |
| `erased_flag_column` | Depends on path | `is_erased_customer` | Simple identifier for a new FACT output flag, existing policy-applied FACT output flag, or existing CASE_VIEW input flag |
| `deletion_relation` | No | `ref('int_terminal_deleted_customer_keys')` | Alternate terminal ledger, intended for tests or an explicitly isolated control implementation |
| `source_is_mode_annotated` | No | `false` | Reuses an existing mode column and skips ledger attachment; mutually exclusive with `source_is_policy_applied` and invalid for CASE_VIEW |
| `source_is_policy_applied` | No | `false` | FACT-only projection of a source that already contains erased keys and the erased flag; mutually exclusive with `source_is_mode_annotated` |
| `deletion_mode_column` | No | `deletion_mode` | Simple identifier read by the policy stage; use a custom value only with an already mode-annotated source |
| `additional_predicate` | CASE_VIEW only | `none` | Required nonempty authorization SQL for CASE_VIEW; rejected by every other path |

### Standard FACT

```jinja
{{ generate_customer_deletion_model(
    model_name='fct_order',
    model_type='FACT',
    source_relation=ref('int_orders_classified'),
    primary_key=['order_id'],
    output_columns=['order_id', 'customer_key', 'service_key', 'amount'],
    special_replacement_columns=['customer_key', 'service_key'],
    erased_flag_column='is_erased_customer'
) }}
```

The macro left joins the terminal ledger on `source_rows.customer_key`, removes FULL rows, retains
ordinary and SPECIAL rows, replaces both declared keys on SPECIAL rows, and appends
`is_erased_customer`. For this standard FACT path, the new erased flag must not already occur in
`output_columns`.

### Delete-style model

```jinja
{{ generate_customer_deletion_model(
    model_name='int_customer_orders',
    model_type='SERVICE',
    source_relation=ref('int_customer_orders_keyed'),
    primary_key=['order_version_key'],
    output_columns=[
        'order_version_key', 'customer_key', 'order_key', 'valid_from', 'valid_to'
    ]
) }}
```

`DIMENSION`, `MAPPING`, `SERVICE`, `QUARANTINE`, `IDENTITY`, and `DEPENDENT` remove both FULL and
SPECIAL rows. They reject `special_replacement_columns`; because the default erased flag is not
passed into the delete policy, it does not add an output column.

### Already mode-annotated source

Set `source_is_mode_annotated=true` when upstream classification has already attached the effective
mode and later business logic needed the original key before final policy application:

```jinja
{{ generate_customer_deletion_model(
    model_name='int_invoice_resolution',
    model_type='FACT',
    source_relation='classified_rows',
    primary_key='invoice_id',
    output_columns=['invoice_id', 'customer_key', 'invoice_key'],
    special_replacement_columns=['customer_key', 'invoice_key'],
    erased_flag_column='is_erased_customer',
    source_is_mode_annotated=true,
    deletion_mode_column='deletion_mode'
) }}
```

This path skips the ledger join and reads `deletion_mode_column` from `source_relation`. Any
`customer_key_expression` is unused because matching has already happened.

### Already policy-applied FACT

Use `source_is_policy_applied=true` only for a downstream FACT projection whose source already
contains erased keys and its erased flag:

```jinja
{{ generate_customer_deletion_model(
    model_name='fct_order',
    model_type='FACT',
    source_relation=ref('int_orders_resolved'),
    primary_key=['order_id'],
    output_columns=[
        'order_id', 'customer_key', 'service_key', 'amount', 'is_erased_customer'
    ],
    special_replacement_columns=['customer_key', 'service_key'],
    erased_flag_column='is_erased_customer',
    source_is_policy_applied=true
) }}
```

This path preserves the columns exactly as supplied instead of applying the policy twice. It still
anti-joins the terminal ledger on `customer_key_column`, preventing a surviving original FULL key
from passing through with a false erased flag. The replacement list remains required and must
include the customer key; every replacement column and the erased flag must already be present in
`output_columns`. It rejects `additional_predicate`.

### CASE_VIEW

```jinja
{{ generate_customer_deletion_model(
    model_name='case_fct_order',
    model_type='CASE_VIEW',
    source_relation=ref('fct_order'),
    primary_key='order_id',
    output_columns=['order_id', 'customer_key', 'service_key', 'amount'],
    erased_flag_column='is_erased_customer',
    additional_predicate=case_access_predicate()
) }}
```

CASE_VIEW requires `additional_predicate`. It applies that authorization predicate and excludes
rows where `erased_flag_column` is true. If `erased_flag_column=none`, it instead requires
`customer_key_column` and excludes rows whose customer key equals `erased_member_key`. CASE_VIEW
rejects replacement columns, `source_is_mode_annotated`, and `source_is_policy_applied`.

### Compile-time validation

The macro fails compilation when any of these contracts is violated:

- a validated identifier such as `model_name`, `customer_key_column`, `deletion_mode_column`, a
  primary-key item, or an output column contains punctuation, whitespace, quoting, or
  qualification;
- `primary_key` is empty, is neither a string nor list, or names a column outside
  `output_columns`;
- `output_columns` is empty, contains duplicates, or contains non-identifiers;
- the model type is unsupported;
- the two source-state flags are both true;
- a FACT has no replacement columns or erased flag, does not replace its customer key, or names a
  replacement outside the output projection;
- a non-FACT supplies replacement columns;
- ledger attachment has neither a customer key column nor a nonempty key expression;
- CASE_VIEW has no authorization predicate, no erased-row exclusion input, or a non-identifier erased flag;
- an authorization predicate is supplied outside CASE_VIEW;
- a policy-applied source is not a FACT, omits its existing erased flag from the projection, or
  supplies an authorization predicate.

## `generate_customer_deletion_target_relations`

This macro generates the complete five-column deletion-target relation from declarative mappings.
The project wrapper `customer_deletion_target_relations()` calls it with the governed inventory.

### Signature

```jinja
generate_customer_deletion_target_relations(targets)
```

`targets` must be a nonempty list of mappings. Each mapping has this contract:

| Key | Required | Default | Contract |
| --- | --- | --- | --- |
| `target_layer` | Yes | — | Simple SQL identifier |
| `model_name` | Yes | — | Simple SQL identifier; must be unique across the entire list |
| `model_type` | Yes | — | One of the shared model types |
| `target_kind` | No | Derived | `VIEW` for CASE_VIEW and `TABLE` for every other type; an explicit value must agree |

```jinja
{% macro customer_deletion_target_relations() -%}
{{ generate_customer_deletion_target_relations([
    {
        'target_layer': 'layer3',
        'model_name': 'fct_order',
        'model_type': 'FACT'
    },
    {
        'target_layer': 'layer3_case',
        'model_name': 'case_fct_order',
        'model_type': 'CASE_VIEW'
    }
]) }}
{%- endmacro %}
```

The result is a SQL `select * from values` relation with columns in this exact order:

```text
target_layer
target_relation
target_kind
full_deletion_action
special_deletion_action
```

Entries that are not mappings, duplicate `model_name` values, unsupported model types, invalid
identifiers, or mismatched target kinds fail compilation.

## `generate_customer_deletion_target_row`

This lower-level public generator renders one target tuple. Most developers should declare a list
once through `generate_customer_deletion_target_relations`; use the row macro when a single derived
tuple is needed in another generator or diagnostic operation.

### Signature

```jinja
generate_customer_deletion_target_row(
    target_layer,
    model_name,
    model_type,
    target_kind=none
)
```

| Argument | Required | Default | Contract |
| --- | --- | --- | --- |
| `target_layer` | Yes | — | Simple SQL identifier returned as the first tuple value |
| `model_name` | Yes | — | Simple SQL identifier returned as the target relation |
| `model_type` | Yes | — | Shared model type used to derive kind and both actions |
| `target_kind` | No | Derived | `VIEW` for CASE_VIEW and `TABLE` otherwise; matching is case-insensitive |

Example:

```jinja
{{ generate_customer_deletion_target_row(
    target_layer='layer3',
    model_name='fct_order',
    model_type='FACT'
) }}
```

Output:

```text
('layer3', 'fct_order', 'TABLE', 'DELETE_CURRENT_ROWS', 'REASSIGN_TO_ERASED_MEMBER')
```

The macro returns only the tuple text, not a complete `select`. Invalid identifiers, unsupported
types, target kinds outside `TABLE`/`VIEW`, and type/kind mismatches fail compilation.

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
