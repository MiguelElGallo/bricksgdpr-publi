---
title: Bundle job
icon: lucide/workflow
---

# Bundle job

The bundle defines one unscheduled workflow with separate control, build, access, verification,
and failure-recording tasks. Catalog variables are passed explicitly to every dbt command.

## Targets

| Target | Mode / Run As | Analytical default | Evidence default |
| --- | --- | --- | --- |
| `dev` | Development / deployer | `bricksgdpr_dev` | `bricksgdpr_dev_evidence` |
| `validation` | Production / configured service principal | `bricksgdpr_validation` | `bricksgdpr_validation_evidence` |
| `prod` | Production / configured service principal | `bricksgdpr_prod` | `bricksgdpr_prod_evidence` |

`dev` is the default. Its private bundle path isolates workspace files, not concurrent writers:
choose distinct catalog pairs for separate deployers. The other targets use
`/Shared/.bundle/${bundle.name}/${bundle.target}` and require the pre-provisioned application ID in
`run_as_service_principal`. Never deploy multiple jobs that write the same catalog pair concurrently.

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `warehouse_id` | Required | Compatible SQL warehouse |
| `project_catalog` | Target-specific above | Seeds, models, functions, and metadata tests |
| `evidence_catalog` | Target-specific above | Append-only control archives and execution events; must differ from analytical catalog |
| `control_catalog` | `workspace` | Existing catalog for the generated dbt connection; schema is `default` |
| `run_as_service_principal` | Empty | Required application ID for `validation` and `prod` |
| `failure_recipients` | `[]` | Failure notification email list; configure to enable notifications |

Supply reviewed values using `BUNDLE_VAR_<name>` or bundle `--var`. Ensure the Run As identity can
use the warehouse and govern the selected catalogs, functions, and secret reference. These targets
do not provision identities or grant their permissions automatically.

## Tasks

| Task | Dependency | Work |
| --- | --- | --- |
| `prepare_controls` | None | Bootstrap catalogs/evidence; build ancestors through the terminal ledger; record pending targets |
| `build_outputs` | `prepare_controls` | Build all governed outputs and non-access tests; record model outcomes |
| `access_controls` | `build_outputs` | Apply analytical privileges and revoke persona access to evidence |
| `verify` | `access_controls` | Run all tests; record verified outcomes only after required tests and target-completion checks |
| `record_failure` | All four stages; at least one failed | Record a durable `__workflow__` failure event, then fail deliberately to preserve job failure |

Every command shares `deletion_execution_id={{job.run_id}}`. Output and verification stages enable
`track_deletion_execution`. The final stage tests existing outputs instead of rebuilding them a
second time. Control ancestors are deliberately revisited during the output build; full-refresh
protection and archive replay keep their retained state intact.

The controls build uses `--indirect-selection cautious`: a test runs only when all its
dependencies are selected. Tests spanning downstream outputs run during the full build and
verification, after those tables and functions exist.

Full-build and verification selectors quote `"*"` so the job shell passes the wildcard to dbt.
Unmatched selections fail through `NoNodesForSelectionCriteria`. The evidence hook declares its
plan dependency explicitly so dbt can resolve it during post-build compilation.

A repair should restart from `prepare_controls`, preserving the ledger and archive. A failed
warehouse/evidence service can also prevent the failure task from writing: the failed job remains
external evidence of that condition. See [Deletion operations and recovery](deletion-operations.md).

## Runtime settings

| Property | Value |
| --- | --- |
| Resource key / job name | `bricksgdpr_dbt_workflow` |
| Bundle name | `bricksgdpr` |
| Bundle UUID | `5c8a5dea-1acc-4756-9aa5-019b2c949c82` |
| Minimum CLI | `1.7.0` |
| Maximum concurrent job runs | 1 |
| Job / task timeout | 3,600 seconds each |
| Automatic retries / retry on timeout | 0 / false |
| Serverless auto-optimization retries | Disabled on every task |
| dbt source / project directory | `WORKSPACE` / `../` |
| Environment | `dbt_environment`, version `4` |
| Dependencies | `dbt-core==1.11.12`, `dbt-databricks==1.12.2` |

Account provisioning, temporary-persona acceptance, and recovery rehearsal remain separate private
workflows. `acceptance/**`, `docs/**`, `scripts/**`, and `profiles.yml` are excluded from bundle
synchronization. Databricks generates a run-scoped dbt connection; local OAuth profiles are not
uploaded. Key rotation and physical-erasure tracking are not implemented.

Sources: `databricks.yml`, `resources/bricksgdpr.job.yml`.
