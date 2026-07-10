---
title: Bundle job
icon: lucide/workflow
---

# Bundle job

The Databricks Asset Bundle defines one development target and one unscheduled dbt workflow.

## Bundle

| Property | Value |
| --- | --- |
| Bundle name | `bricksgdpr` |
| UUID | `5c8a5dea-1acc-4756-9aa5-019b2c949c82` |
| Minimum Databricks CLI | `1.7.0` |
| Included configuration | `resources/*.yml` |
| Default target | `dev` |
| Target mode | `development` |
| Workspace host | Selected by the explicit Databricks CLI profile; not checked in |
| Variable | `warehouse_id` |
| Variable default | None; `BUNDLE_VAR_warehouse_id` or `--var` is required |

**Source:** `databricks.yml`.

## Synchronization exclusions

| Excluded path | Reason in bundle behavior |
| --- | --- |
| `acceptance/**` | Persona acceptance is a separate explicit workflow |
| `docs/**` | Documentation is not required by the dbt task |
| `scripts/**` | Local identity and fixture helpers are not job inputs |
| `profiles.yml` | Databricks generates a run-scoped dbt connection for the task |

## Job

| Property | Value |
| --- | --- |
| Resource key | `bricksgdpr_dbt_workflow` |
| Job name | `bricksgdpr_dbt_workflow` |
| Schedule | None |
| Maximum concurrent runs | 1 |
| Job timeout | 3,600 seconds |
| Task key | `build_and_validate` |
| Task timeout | 3,600 seconds |
| Retries | 0 |
| Retry on timeout | `false` |
| dbt source | `WORKSPACE` |
| Project directory | `../` |
| SQL warehouse | `${var.warehouse_id}` |
| Control catalog/schema | `workspace.default` |

## Task commands

The single task runs these commands in order:

```text
dbt run-operation bootstrap_project_catalog
dbt build --exclude tag:access_control
dbt run-operation apply_access_controls
dbt test --select tag:access_control
dbt build
```

## Job environment

| Property | Value |
| --- | --- |
| Environment key | `dbt_environment` |
| Environment version | `4` |
| Dependency | `dbt-core==1.11.12` |
| Dependency | `dbt-databricks==1.12.2` |

The versions match `pyproject.toml`.

## Scope boundaries

The job builds dbt resources and validates dbt data/access tests. It does not:

- create or verify the secret scope/key;
- enforce pepper-value immutability or the secret-scope ACL;
- provision persistent account identities or groups;
- run temporary-principal persona acceptance;
- implement physical erasure or backup handling.

The `dev` target writes the canonical project catalog by default. Its job is intended for one
deployer unless ownership and catalog isolation are redesigned.

**Sources:** `resources/bricksgdpr.job.yml`, `databricks.yml`.
