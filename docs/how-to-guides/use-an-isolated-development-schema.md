---
icon: lucide/boxes
---

# Use an isolated development schema

Set `DBT_SCHEMA_PREFIX` when several development builds need distinct data-schema names inside the
same project catalog.

This isolates relation names. It is not a separate catalog, identity boundary, or secret store.

## Load the base environment

```bash
set -a
source .env
set +a
```

## Choose a prefix

Use a short identifier containing characters accepted in a schema name:

```bash
export DBT_SCHEMA_PREFIX="dev_alice"
```

With this example, the Layer3 schema becomes `dev_alice_layer3`. Replace `alice` with a short,
stable identifier for your development environment.

## Confirm dbt's relation names

Parse with the prefix and inspect one manifest entry:

```bash
uv run --locked dbt parse --profiles-dir .
jq -r '.nodes["model.bricksgdpr.dim_customer"].relation_name' target/manifest.json
```

The result should end with:

```text
dev_alice_layer3.dim_customer
```

The catalog prefix depends on `DBT_PROJECT_CATALOG`.

## Build the development slice

For example:

```bash
uv run dbt build --select +tag:layer3
```

dbt writes the selected data relations into the prefixed schemas.

!!! warning
    Functions remain in the stable `priva_internal` schema. The project does this so Unity Catalog
    column-mask references do not drift. Do not treat `DBT_SCHEMA_PREFIX` as a complete security
    isolation mechanism.

    The temporary-principal persona validator is also unavailable for this prefixed build. Its SQL
    templates are rendered for the reviewed catalog, but require unprefixed schemas.

## Return the shell to the default

```bash
unset DBT_SCHEMA_PREFIX
uv run --locked dbt parse --profiles-dir .
```

This restores unprefixed relation naming for later commands. It does not delete previously created
remote schemas or relations; remote cleanup is intentionally not implemented by this repository.

Consult [Project configuration](../reference/configuration.md) for the variable contract and
[Architecture and trust boundaries](../explanation/architecture-and-trust-boundaries.md) for the
stable-function boundary.
