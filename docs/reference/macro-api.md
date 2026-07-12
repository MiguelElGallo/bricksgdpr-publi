---
title: Macro API reference
icon: lucide/braces
---

# Macro API reference

This is the complete developer API for generating customer-deletion-aware dbt models and their
deletion-target registrations. Start with `generate_customer_deletion_scaffold` for a new model,
then keep the emitted `generate_customer_deletion_model` call and declarative target mapping under
source control.

Only these four public generation macros are covered:

| Macro | Use it to |
| --- | --- |
| `generate_customer_deletion_scaffold` | Preview the model SQL, target mapping, derived action row, and schema YAML for one model |
| `generate_customer_deletion_model` | Generate the governed SQL `select` inside a dbt model |
| `generate_customer_deletion_target_relations` | Generate the complete deletion-target relation from model mappings |
| `generate_customer_deletion_target_row` | Generate one validated target tuple, normally through the relations macro |

The generated `customer_deletion_generated_contract` data test is an output of the scaffold, not a
model-generation API. The lower-level policy macros, SQL-expression helpers, project hooks, access
control operations, schema naming override, and private macros whose names begin with `_` are also
outside this API.

## Shared model types

All four macros use the same case-insensitive `model_type` values and derive deletion behavior from
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

Use this as the entry point for a new or migrated model. It validates the declaration and prints
all source-controlled artifacts without writing files or changing warehouse data.

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
| `customer_key_kind` | No | `text` | Nonempty canonicalization kind paired with `customer_key_domain`, normally `text`, `ssn`, `phone`, or `date` |
| `special_replacement_columns` | FACT only | `none` | Nonempty list of output keys replaced with `erased_member_key`; it must include `customer_key_column` |
| `erased_flag_column` | No | `is_erased_customer` for FACT; otherwise `none` | FACT output flag or CASE_VIEW input flag; an already-policy-applied FACT must already include it in `output_columns` |
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

For an expression the scaffold cannot derive, pass `customer_key_expression` with the required
`source_rows.` alias. The scaffold rewrites that alias to `generated_model.` in the emitted test.

### Scaffold limits

The scaffold intentionally exposes the supported common path. It does not accept
`source_is_mode_annotated`, `deletion_relation`, `deletion_mode_column`, or an arbitrary
`additional_predicate`. Use the emitted model call as the starting point and set those advanced
arguments directly on `generate_customer_deletion_model` when their contracts below apply.

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
| `erased_flag_column` | Depends on path | `is_erased_customer` | New FACT output flag, existing policy-applied FACT output flag, or existing CASE_VIEW input flag |
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
- CASE_VIEW has no authorization predicate or no erased-row exclusion input;
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

## Add and validate a generated model

After running the scaffold:

1. Save the emitted model call in the correct `models/` SQL file.
2. Append the emitted mapping to `customer_deletion_target_relations()`; do not copy or maintain
   action strings by hand.
3. Add the emitted schema YAML beside the model.
4. Add a model-specific unit test when business rules go beyond the generated deletion contract.
5. Update fixed target counts and walkthrough fixtures if the governed inventory changed.

Validate the integration with focused dbt commands:

```bash
uv run dbt build --select +fct_order
uv run dbt test --select test_name:customer_deletion_generated_contract
uv run dbt test --select assert_customer_deletion_generators
uv run dbt test --select tag:deletion_control
```

The generated contract verifies model grain and deletion mechanics. It cannot infer whether
measures, dates, joins, or other model-specific business rules are correct.

**Implementation and argument metadata:** `macros/customer_deletion_generators.sql` and
`macros/customer_deletion_generators.yml`.
