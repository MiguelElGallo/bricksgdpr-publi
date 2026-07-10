---
icon: lucide/rocket
---

# Build and explore the demo

In this tutorial, we will prepare a shell, build the complete dbt project, and inspect the
deterministic results.

The goal is not merely a successful command. We will use the result to form a first picture of
how accepted, quarantined, and protected records fit together.

## Before you begin

Use a Databricks workspace where the
[first deployment](../how-to-guides/deploy-the-demo-for-the-first-time.md)
has been completed. You also need:

- the repository checked out locally;
- a configured `.env` file;
- the authenticated Databricks CLI profile named by `DATABRICKS_CONFIG_PROFILE`; and
- the checked-in synthetic seeds unchanged.

If the local environment is not ready, complete
[Configure a development environment](../how-to-guides/configure-a-development-environment.md)
first.

!!! warning
    The build writes the catalog named by `DBT_PROJECT_CATALOG`. The example configuration points
    to the canonical `bricksgdpr` catalog, not a disposable local database.

## Load the project environment

From the repository root, export the values in `.env` into the current shell:

```bash
set -a
source .env
set +a
```

Install the pinned dbt packages and the development tools:

```bash
uv sync --locked
```

Now parse the project:

```bash
uv run --locked dbt parse --profiles-dir .
```

A successful parse creates dbt artifacts under `target/` and reports no parsing error. No model
has been executed yet.

## Preview the path to Layer3

dbt selectors describe a part of the dependency graph. The leading `+` includes upstream nodes.

```bash
uv run dbt ls --select +tag:layer3 --output name
```

Notice that the list reaches beyond the five Layer3 dimensions and facts. Layer3 depends on the
source seeds, functions, mappings, and protected Layer2 models that prepare its inputs.

## Build and secure the project

Build relations before testing the live access-control metadata:

```bash
uv run dbt build --select '*' --exclude tag:access_control
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
uv run dbt build --select '*'
```

The second command reconciles parent privileges and revokes consumer access to the internal SQL
functions. The final `dbt build` runs the complete model and test graph after those controls are in
place.

!!! success
    Continue only when every command succeeds. A green model build without the access-control
    tests is not the complete project contract.

## Inspect the fixture partitions

Use `dbt show` to query the built relations through dbt's own `ref()` resolution:

```bash
uv run dbt show --inline '
select
    (select count(*) from {{ ref("int_customer_protected") }}) as protected_customers,
    (select count(*) from {{ ref("int_customer_events_resolved") }}) as accepted_events,
    (select count(*) from {{ ref("quarantine_customer_events") }}) as quarantined_events,
    (select count(*) from {{ ref("int_customer_services_resolved") }}) as accepted_services,
    (select count(*) from {{ ref("quarantine_customer_services") }}) as quarantined_services,
    (select count(*) from {{ ref("int_invoices_resolved") }}) as accepted_invoices,
    (select count(*) from {{ ref("quarantine_invoices") }}) as quarantined_invoices
' --limit 1
```

With the checked-in fixtures, the result is:

| protected customers | accepted events | quarantined events | accepted services | quarantined services | accepted invoices | quarantined invoices |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 14 | 28 | 1 | 16 | 3 | 25 | 11 |

The quarantine relations are intentional outputs. They keep unresolved or invalid source records
observable instead of silently dropping them from the pipeline.

## What you have built

You have built the synthetic source extracts, typed Layer1 views, raw quarantine tables, two
`priva_map` tables, protected Layer2 models, Layer3 dimensions and facts, and controlled case
views. You have also applied and tested the exact access contract.

Next, [follow one customer through those layers](follow-a-customer-through-the-layers.md).

For exact relation definitions, see the
[catalog and schema reference](../reference/catalogs-and-schemas.md). For the design rationale, see
[Architecture and trust boundaries](../explanation/architecture-and-trust-boundaries.md).
