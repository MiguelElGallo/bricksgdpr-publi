---
title: Commands
icon: lucide/terminal
---

# Commands

Commands are shown from the repository root. Their effects are independent; this page does not
define an execution sequence.

## Environment and static validation

| Command | Effect | External mutation |
| --- | --- | --- |
| `uv sync --locked` | Installs the locked runtime and development dependency groups | Local environment only |
| `uv run python scripts/generate_seeds.py` | Rewrites the four deterministic seed CSVs | Repository seed files |
| `uv run ruff check .` | Runs Python lint checks | None |
| `uv run ty check scripts` | Runs Python type checks for `scripts/` | None |
| `uv run --locked dbt parse --profiles-dir .` | Parses the project and writes dbt artifacts | Local `target/` and logs only |
| `databricks current-user me --profile "$DATABRICKS_CONFIG_PROFILE" >/dev/null` | Proves the local OAuth session can call the workspace API without printing identity | None |
| `uv run dbt debug --profiles-dir .` | Verifies local dbt configuration and live connectivity | None |
| `uv run dbt ls --select <selection>` | Lists selected graph nodes | Local artifacts/logs only |
| `scripts/check_publication_safety.sh --tree` | Scans tracked and non-ignored files for account identifiers, Personal Data, and credential patterns with redacted output | None |
| `scripts/check_publication_safety.sh --history` | Scans commits reachable from publishable Git refs with redacted output | None |

**Sources:** `README.md`, `pyproject.toml`, `scripts/generate_seeds.py`.

GitHub Actions runs deterministic seeds, Ruff, ty, Bash syntax, and `dbt parse`. Pull requests use
reserved placeholders; pushes to `main` and manual runs selected on `main` use only the encrypted
host and HTTP-path identifiers. Manual runs from other refs use placeholders. Live commands in
this page remain local.

## Catalog, build, and test commands

| Command | Effect |
| --- | --- |
| `uv run dbt run-operation bootstrap_project_catalog` | Creates the analytical and separate evidence catalogs when absent |
| `uv run dbt build --select '*' --exclude tag:access_control` | Builds seeds, functions, models, unit tests, and non-access data tests |
| `uv run dbt run-operation apply_access_controls` | Applies parent grants and the macro's explicit revocations |
| `uv run dbt test --select tag:access_control` | Runs the live Unity Catalog access tests, including evidence isolation |
| `uv run dbt build --select '*'` | Executes the complete dbt graph |
| `uv run dbt build --full-refresh --exclude tag:access_control` | Rebuilds replaceable relations; preserves the three durable controls |
| `uv run dbt test --select tag:deletion_control` | Runs tests tagged for terminal-deletion behavior |
| `uv run dbt test --select assert_priva_map_contract` | Runs the exact default mapping fixture contract |

`apply_access_controls` is not a universal privilege reset. Unexpected schema privileges detected
by the access tests can require separate operator remediation.

## Focused graph selections

| Command | Selected subject |
| --- | --- |
| `uv run dbt build --select +tag:layer1` | Layer1 nodes and all upstream dependencies |
| `uv run dbt build --select +tag:priva_map` | Mapping nodes and all upstream dependencies |
| `uv run dbt build --select "+tag:layer2 +tag:quarantine"` | Layer2 and quarantine nodes with upstream dependencies |
| `uv run dbt build --select +tag:layer3` | Layer3 nodes and all upstream dependencies |
| `uv run dbt build --select +tag:case_views` | Case views and all upstream dependencies |

The project defines no named selectors. `+` is dbt's graph operator for upstream ancestry in these
forms.

## Identity and persona commands

| Command | Mode | Effect |
| --- | --- | --- |
| `scripts/provision_identities.sh` | Read-only | Alias of `--preflight-only`; verifies target and identity topology and reports planned creation |
| `scripts/provision_identities.sh --preflight-only` | Read-only | Verifies exact host/caller/warehouse, identities, groups, memberships, and warehouse permissions |
| `scripts/provision_identities.sh --apply` | Mutating | Creates or reconciles the permitted account groups/users, workspace assignments, memberships, and group warehouse permissions |
| `scripts/validate_personas.sh --apply` | Mutating with cleanup | Creates temporary service principals and jobs, validates positive/denial task states, and deletes temporary resources |

The persona validator renders `DBT_PROJECT_CATALOG` into temporary SQL and requires an empty
schema prefix. The reviewed catalog must match `[a-z][a-z0-9_]*`.

## Databricks Asset Bundle commands

| Command | Effect |
| --- | --- |
| `databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE"` | Validates bundle structure and target configuration |
| `databricks bundle plan --profile "$DATABRICKS_CONFIG_PROFILE"` | Displays planned workspace changes |
| `databricks bundle deploy --profile "$DATABRICKS_CONFIG_PROFILE"` | Deploys the `dev` target |
| `databricks bundle summary --profile "$DATABRICKS_CONFIG_PROFILE"` | Displays deployed resource URLs and identifiers |
| `databricks bundle run bricksgdpr_dbt_workflow --profile "$DATABRICKS_CONFIG_PROFILE"` | Starts the unscheduled dbt workflow |
| `databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE" --var="warehouse_id=<warehouse-id>"` | Validates with a command-scoped warehouse override |

**Sources:** `README.md`, `databricks.yml`, `resources/bricksgdpr.job.yml`.
