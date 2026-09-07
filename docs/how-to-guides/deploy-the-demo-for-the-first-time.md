---
icon: lucide/package-plus
---

# Deploy the demo for the first time

This guide creates the project catalog and fixed `v1` secret, provisions the three persona groups,
builds all governed relations, and applies the access contract.

Use it once for a new target. For routine job deployment, use
[Deploy and run the Databricks bundle](deploy-and-run-the-databricks-bundle.md).

## Prerequisites

Complete [Configure a development environment](configure-a-development-environment.md). The
authenticated caller must be allowed to create a Unity Catalog catalog, account groups and users,
SQL functions, and the Databricks secret scope. `openssl` is required to generate the pepper.

Load the reviewed target values:

```bash
set -a
source .env
set +a
```

!!! danger
    The example environment targets the canonical `bricksgdpr` catalog. Confirm
    `DBT_PROJECT_CATALOG`, `DATABRICKS_EXPECTED_HOST`, and `DATABRICKS_EXPECTED_CALLER` before any
    mutating command.

## Create the catalog

```bash
uv run dbt run-operation bootstrap_project_catalog
```

The operation creates the analytical catalog and a distinct evidence catalog with append-only
control-history and execution-event tables. Set `DBT_EVIDENCE_CATALOG` explicitly when needed.
New evidence objects have no persona grants; later access reconciliation enforces that boundary.

## Check for an existing `v1` pepper

List the secret scopes first:

```bash
databricks secrets list-scopes --profile "$DATABRICKS_CONFIG_PROFILE"
```

If `bricksgdpr` is absent, create it:

```bash
databricks secrets create-scope bricksgdpr \
  --profile "$DATABRICKS_CONFIG_PROFILE"
```

Now list the keys in that scope:

```bash
databricks secrets list-secrets bricksgdpr \
  --profile "$DATABRICKS_CONFIG_PROFILE"
```

!!! danger
    If `pepper_v1` appears, stop. Do not run `put-secret`: that command can overwrite an existing
    value, which would silently change the meaning of every future `v1:` key.

## Create the `v1` pepper once

Only after confirming that `pepper_v1` is absent, create it:

```bash
openssl rand -base64 48 \
  | databricks secrets put-secret bricksgdpr pepper_v1 \
      --profile "$DATABRICKS_CONFIG_PROFILE"
```

The command pipes the generated secret directly to Databricks. It does not belong in `.env`, dbt
variables, logs, tags, or tables.

!!! warning
    Never overwrite `bricksgdpr/pepper_v1` in place. The `pseudonymize_personal_data_v1` function
    and every `v1:` key depend on that immutable pairing. Rotation requires a new versioned key,
    wrapper, and parallel columns.

The repository references the fixed scope and key, but it does not prevent an operator from
overwriting the secret or test the secret-scope ACL. Immutability and the rule that only the
deployment identity receives secret `READ` are external operator controls that must be reviewed
and audited separately.

## Provision the persona topology

Follow [Provision persona identities](provision-persona-identities.md). For the repository-owned
demo users, select synthetic mode and return here after the post-apply preflight passes.

## Build relations and reconcile privileges

Run the sequence in this order:

```bash
uv run dbt build --select '*' --exclude tag:access_control
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
uv run dbt build --select '*'
```

The initial build creates the relations and applies their relation-level `SELECT` grants. The
operation then grants required parent `USE` privileges and revokes broad or internal-function
access. The access tests compare live Unity Catalog metadata with the exact allowlist.

## Validate the data plane

```bash
scripts/validate_personas.sh --apply
```

This creates three temporary service principals, runs the positive and expected-denial SQL tasks,
then deletes the principals and uploaded workspace files. See
[Validate persona access](validate-persona-access.md) before running it.

## Confirm the deployment

Use [Build and explore the demo](../tutorials/build-and-explore-the-demo.md) to check the current
fixture counts and inspect the governed layers.

For the exact schema and reader matrix, consult
[Catalogs and schemas](../reference/catalogs-and-schemas.md). Read
[Demo and production boundaries](../explanation/demo-and-production-boundaries.md) before adapting
this single-deployer target to a shared environment.
