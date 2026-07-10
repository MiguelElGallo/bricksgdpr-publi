---
icon: lucide/workflow
---

# Deploy and run the Databricks bundle

This guide validates, plans, deploys, and runs the repository's `bricksgdpr_dbt_workflow` job.

The default `dev` bundle target has no schedule. It writes the canonical demo catalog and is
intended for one deployer.

## Prerequisites

Complete the [first deployment](deploy-the-demo-for-the-first-time.md), including the secret,
persona groups, and access controls. Authenticate the CLI profile named in the reviewed `.env`
and source that file; this supplies `DATABRICKS_CONFIG_PROFILE` and the required
`BUNDLE_VAR_warehouse_id`.

## Validate the bundle

```bash
databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE"
```

Validation should resolve the `dev` target, the `bricksgdpr_dbt_workflow` job, and the configured
SQL warehouse without an error.

## Inspect the plan

```bash
databricks bundle plan --profile "$DATABRICKS_CONFIG_PROFILE"
```

Review every proposed workspace change before continuing.

!!! warning
    Deployment changes workspace state. Stop if the plan targets an unexpected workspace path,
    job, warehouse, or catalog.

## Deploy and summarize

```bash
databricks bundle deploy --profile "$DATABRICKS_CONFIG_PROFILE"
databricks bundle summary --profile "$DATABRICKS_CONFIG_PROFILE"
```

The summary should show one deployed job named `bricksgdpr_dbt_workflow` under the deployer's
private bundle workspace path.

## Run the workflow

```bash
databricks bundle run bricksgdpr_dbt_workflow \
  --profile "$DATABRICKS_CONFIG_PROFILE"
```

The job's `build_and_validate` task performs this sequence:

1. bootstrap the project catalog;
2. build every governed relation except the live access-control tests;
3. apply access controls;
4. run the access-control tests; and
5. run the complete dbt build.

Serverless Jobs compute runs the pinned dbt environment. The configured SQL warehouse executes
the generated SQL.

## Use another compatible warehouse

Override the reviewed environment value only when the target warehouse is serverless or pro and
is intended for this deployment:

```bash
databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE" \
  --var="warehouse_id=<warehouse-id>"
```

The variable applies to that command. Supply the same reviewed override to later bundle commands
that must use it.

!!! note
    The bundle excludes `acceptance/**`, `docs/**`, `scripts/**`, and `profiles.yml` from workspace
    synchronization. Account identity provisioning and temporary-persona acceptance remain
    separate explicit operations.

Consult the [bundle job reference](../reference/bundle-job.md) for exact timeouts, dependencies,
and synchronization rules.
