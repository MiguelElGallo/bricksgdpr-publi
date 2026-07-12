---
icon: lucide/wand-sparkles
---

# Generate a customer-deletion model

Use the developer generator whenever a new model contains a customer key or depends on a customer.
You declare the grain and model type; the generator derives the FULL and SPECIAL behavior.

You do not need to call the lower-level attach/apply macros or hand-write deletion-plan actions.

## 1. Choose the model type

| `model_type` | SPECIAL behavior | FULL behavior | Typical models |
| --- | --- | --- | --- |
| `FACT` | Replace declared keys with `-99999`; set erased flag | Remove row | Events, invoices, orders |
| `DIMENSION` | Remove customer-dependent row | Remove row | Customer or service dimensions |
| `MAPPING` | Remove mapping row | Remove row | Restricted readable-value maps |
| `SERVICE` | Remove service row | Remove row | Customer-owned service periods |
| `QUARANTINE` | Remove readable rejected row | Remove row | Personal Data quarantine tables |
| `IDENTITY` / `DEPENDENT` | Remove row | Remove row | Other customer-dependent outputs |
| `CASE_VIEW` | Exclude erased row | Already absent upstream | Authorized readable views |

The generator rejects unsupported types. FACT also fails compilation unless it declares at least one
replacement key and an erased-row flag.

## 2. Preview every required artifact

Run the scaffold operation with the model contract:

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
  customer_key_column: customer_key
  special_replacement_columns:
    - customer_key
    - service_key
'
```

[`dbt run-operation`](https://docs.getdbt.com/reference/commands/run-operation) maps the YAML
arguments to the generator macro. This operation is preview-only: it prints source-controlled code
and never writes files or changes warehouse data.

The output contains four sections:

1. the complete model SQL call;
2. the declarative target-registry entry;
3. the exact target row derived from `model_type`;
4. schema documentation plus structural and deletion-contract tests.

## 3. Add the generated model call

Create `models/layer3/fct_order.sql` using the printed call:

```jinja
{{ generate_customer_deletion_model(
    model_name='fct_order',
    model_type='FACT',
    source_relation=ref('int_orders_classified'),
    primary_key=['order_id'],
    output_columns=['order_id', 'customer_key', 'service_key', 'amount'],
    customer_key_column='customer_key',
    special_replacement_columns=['customer_key', 'service_key'],
    erased_flag_column='is_erased_customer'
) }}
```

This single call generates the ledger join, explicit projection, SPECIAL key replacement, erased
flag, FULL exclusion, and ordinary-row behavior.

If a Layer3 fact reads an upstream relation where this policy has already run, preserve that state
instead of joining the original-key ledger again:

```jinja
{{ generate_customer_deletion_model(
    model_name='fct_order',
    model_type='FACT',
    source_relation=ref('int_orders_resolved'),
    primary_key=['order_id'],
    output_columns=[
        'order_id', 'customer_key', 'service_key', 'amount', 'is_erased_customer'
    ],
    customer_key_column='customer_key',
    special_replacement_columns=['customer_key', 'service_key'],
    erased_flag_column='is_erased_customer',
    source_is_policy_applied=true
) }}
```

The generator requires the erased flag in this projection. The generated contract verifies that
every flagged row still carries the erased keys, and the generated projection anti-joins the
terminal ledger so a leaked original FULL key cannot pass through with a false flag.

For a service table, omit the FACT-only arguments:

```jinja
{{ generate_customer_deletion_model(
    model_name='int_customer_orders',
    model_type='SERVICE',
    source_relation=ref('int_customer_orders_keyed'),
    primary_key=['order_version_key'],
    output_columns=[
        'order_version_key', 'customer_key', 'order_key', 'valid_from', 'valid_to'
    ],
    customer_key_column='customer_key'
) }}
```

Both modes are removed from that output because `SERVICE` is a delete-style contract.

For a raw quarantine table, provide the expression used to calculate the ledger key. The scaffold
derives the test expression by changing the required `source_rows` alias to `generated_model`:

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

The resulting model calculates the pseudonymous ledger key for matching but retains the declared
raw quarantine columns only for nondeleted customers. Its generated contract calculates the same
key from `generated_model.customer_ssn` using the declared domain and canonicalization kind; it does
not compare a raw SSN directly with a hashed key.

For a case view, the scaffold automatically emits `additional_predicate=case_access_predicate()`.
Leave `erased_flag_column` null for dimensions so the generator excludes `customer_key = -99999`;
set it to `is_erased_customer` for case facts.

## 4. Register the target declaratively

Append the printed mapping to the list in `customer_deletion_target_relations()`:

```jinja
{
    'target_layer': 'layer3',
    'model_name': 'fct_order',
    'model_type': 'FACT'
}
```

Do not write action strings. `generate_customer_deletion_target_relations()` derives them:

```text
('layer3', 'fct_order', 'TABLE',
 'DELETE_CURRENT_ROWS', 'REASSIGN_TO_ERASED_MEMBER')
```

Changing the type to `SERVICE` would derive `DELETE_CURRENT_ROWS` for both modes. `CASE_VIEW`
derives the two exclusion actions and defaults the target kind to `VIEW`.

## 5. Add the generated YAML contract

Copy the emitted schema block beside the model. For a FACT it includes:

```yaml
- name: fct_order
  description: >
    One governed row per order_id. Customer deletion behavior is generated from the FACT contract
    so FULL and SPECIAL modes cannot diverge by hand.
  data_tests:
    - customer_deletion_generated_contract:
        arguments:
          model_type: FACT
          primary_key: [order_id]
          customer_key_columns: [customer_key, service_key]
          erased_flag_column: is_erased_customer
  columns:
    - name: order_id
      data_tests: [not_null, unique]
    - name: is_erased_customer
      description: True only when SPECIAL retains the fact under the erased member.
      data_tests: [not_null]
```

The generated contract detects null or duplicate grain, null or incomplete FACT key replacement,
incorrect erased flags, original ledger keys surviving FACT projections, erased rows visible
through case views, and ledger keys surviving in delete-style models.

## 6. Validate the generated integration

```bash
uv run dbt build --select +fct_order
uv run dbt test --select test_name:customer_deletion_generated_contract
uv run dbt test --select assert_customer_deletion_generators
uv run dbt test --select tag:deletion_control
```

Add a fixture-specific unit test when the model has additional business rules. The generic contract
proves deletion mechanics; it cannot infer whether measures, dates, or model-specific joins are
correct.

## Advanced inputs

- Use `primary_key=[...]` for a composite grain.
- Use `customer_key_expression` when the input key must be calculated rather than read from one
  column.
- Prefer `customer_key_domain` plus `customer_key_kind` in scaffolds for raw Personal Data; this
  generates matching model and test expressions without nested Jinja in YAML.
- Use `source_is_mode_annotated=true` when earlier classification logic already carries
  `deletion_mode`.
- Use `source_is_policy_applied=true` for downstream FACT projections that already carry erased
  keys and the erased flag. Never combine it with `source_is_mode_annotated`.
- Direct generator calls must provide `additional_predicate` for `CASE_VIEW`; the scaffold inserts
  `case_access_predicate()` automatically.
- Override `deletion_relation` only in unit tests or an explicitly isolated control implementation.

The generator validates these combinations during compilation and fails before executing malformed
SQL.
