---
icon: lucide/shield-check
---

# Prove a protected-layer invariant

In this tutorial, we will prove the project's metadata invariant: Layer2 and Layer3 contain no
columns that the checked naming and tag contracts identify as readable Personal Data.

This project treats security metadata as executable behavior. A model is not accepted merely
because its SQL looks safe.

## Inspect a protected row

Start with the Layer3 customer dimension:

```bash
uv run dbt show --inline '
select
    customer_key,
    customer_id_key,
    full_name_key,
    email_key,
    customer_segment,
    is_active
from {{ ref("dim_customer") }}
' --limit 3
```

The identifying fields end in `_key` and contain versioned pseudonymous values. The business
segment and active flag remain readable because the project does not classify them as direct
identifiers in this model.

## Run the Layer2 metadata test

```bash
uv run dbt test --select assert_layer2_no_raw_columns
```

The singular test queries `system.information_schema.columns`. It fails if a protected Layer2
relation exposes a name such as `customer_ssn`, `email`, `address`, or an unexpected `_value`
column.

The numeric event column `measure_value` is an explicit exception: it is a measure, not a raw
identity value.

## Run the Layer3 metadata test

```bash
uv run dbt test --select assert_layer3_no_raw_columns
```

The test applies the same forbidden-name contract to all five Layer3 dimensions and facts.

Now reject any Layer2 or Layer3 column explicitly tagged as raw or controlled-readable:

```bash
uv run dbt test --select assert_protected_no_readable_tags
```

!!! success
    All three commands should report `PASS`. In a singular dbt test, success means the test query
    returned zero violating rows.

!!! warning "What this invariant cannot prove"
    These tests are naming and tag heuristics. They cannot detect readable content hidden under an
    arbitrary innocent-looking column name or content that was misclassified before tagging.
    Schema contracts, fixture tests, data inspection, and review remain necessary.

## Connect the test to the DAG

List the protected models selected by their layer tags:

```bash
uv run dbt ls --select "tag:layer2 tag:layer3" --resource-type model --output name
```

The result should include the protected customer, event, service, and invoice models and the
Layer3 dimensions and facts. The raw Layer1, `priva_map`, and controlled case-view schemas are
different security zones and are not the subject of these two tests.

## What you have proved

You have not just inspected one safe-looking row. You have executed the catalog-wide naming and
tag checks that guard the protected schemas against declared readable Personal Data fields.

Continue with the [how-to guides](../how-to-guides/index.md) when you need to operate or change the
project.

For the broader assurance model, read
[Executable security controls](../explanation/executable-security-controls.md). For the complete
selector inventory, use [Tests and selectors](../reference/tests-and-selectors.md).
