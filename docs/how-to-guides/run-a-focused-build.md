---
icon: lucide/target
---

# Run a focused build

Use a focused build when you need to execute one governed layer and all inputs required to make
that result self-consistent.

## Load the environment

```bash
set -a
source .env
set +a
```

## Preview the selector

For example, preview Layer3 and its upstream dependencies:

```bash
uv run dbt ls --select +tag:layer3 --output name
```

The leading `+` means “include ancestors.” Review the list before executing it.

## Build the selected slice

Choose the slice that matches the work:

```bash
uv run dbt build --select +tag:layer1
uv run dbt build --select +tag:priva_map
uv run dbt build --select "+tag:layer2 +tag:quarantine"
uv run dbt build --select +tag:layer3
uv run dbt build --select +tag:case_views
```

Run one command, not the whole block. `dbt build` executes the selected resources and their tests;
it is preferred here over a model-only `dbt run`.

!!! tip
    Keep the quotes around the combined Layer2 selector. The space joins two selections, while the
    leading `+` on each includes the required upstream graph.

## Verify the result

Preview the output you changed with `dbt show`. For example:

```bash
uv run dbt show --inline '
select customer_key, customer_segment, is_active
from {{ ref("dim_customer") }}
' --limit 10
```

Check the row shape and values that matter to your change. Do not treat a successful command as a
substitute for inspecting the result.

If the change affects grants, masks, or case access, also follow
[Reconcile access controls](reconcile-access-controls.md).

Consult [Tests and selectors](../reference/tests-and-selectors.md) for the full selector contract.
