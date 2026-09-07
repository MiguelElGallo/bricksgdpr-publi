---
icon: lucide/workflow
---

# Deploy and run the Databricks bundle

This guide validates, plans, deploys, and runs the repository's `bricksgdpr_dbt_workflow` job.

The default `dev` target is unscheduled and writes `bricksgdpr_dev` plus a separate evidence
catalog. `validation` and `prod` use separate catalog defaults and an explicit service-principal
Run As identity. Select a unique catalog pair for each concurrent deployer.

## Prerequisites

Complete the [first deployment](deploy-the-demo-for-the-first-time.md), including the secret,
persona groups, and access controls. Authenticate the CLI profile named in the reviewed `.env`
and source that file; this supplies `DATABRICKS_CONFIG_PROFILE` and the required
`BUNDLE_VAR_warehouse_id`.

## Select the target and notification settings

Set `BUNDLE_VAR_control_catalog` to an existing catalog when `workspace` is unavailable. For a
shared target, set `BUNDLE_VAR_run_as_service_principal` to the pre-provisioned application ID.
Set `BUNDLE_VAR_failure_recipients` to a JSON array of reviewed email addresses to enable failure
notifications. No notifications are sent with the default empty array.

Use the same `--target validation` or `--target prod` on validate, plan, deploy, summary, and run.
The commands below use `dev`. Review the catalog pair and permissions for the chosen Run As
identity; deploying a bundle does not provision that identity or create the pepper.

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

The job prepares controls and pending evidence, builds outputs, applies access controls, and
verifies all tests in four dependent tasks. A fifth task records a failed workflow if any stage
fails. The final verification does not rebuild the outputs. See
[Deletion operations and recovery](../reference/deletion-operations.md) for status and repair semantics.

Serverless Jobs compute runs the pinned dbt environment. The configured SQL warehouse executes
the generated SQL.

All five tasks disable automatic retries, timeout retries, and serverless auto-optimization
retries. Investigate a failed run before repairing it from `prepare_controls`; see the
[bundle runtime settings](../reference/bundle-job.md#runtime-settings).

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
