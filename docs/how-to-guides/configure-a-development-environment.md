---
icon: lucide/settings
---

# Configure a development environment

This guide configures the checked-in `bricksgdpr` dbt profile to use Databricks OAuth and installs
the repository's pinned Python dependencies.

## Prerequisites

You need:

- Databricks CLI 1.7.0 or newer;
- `uv`;
- access to a Databricks workspace; and
- the repository checked out locally.

Install `jq` as well if you will provision or validate persona identities.

## Create the local environment file

From the repository root:

```bash
cp .env.example .env
git check-ignore -q .env
chmod 600 .env
```

The `git check-ignore` command must succeed. Stop if it does not: a real `.env` is not safe to
populate until Git excludes it.

Fill every blank workspace/account value needed by the workflows you intend to run. Keep
`DATABRICKS_HOST` as a hostname without `https://`; the template derives
`DATABRICKS_EXPECTED_HOST` from it. `BUNDLE_VAR_warehouse_id` likewise follows
`DATABRICKS_WAREHOUSE_ID`.

The public example contains no real workspace host, warehouse ID, account ID, group ID, or
operator email. Those identifiers may exist only in the ignored local copy.

!!! warning
    Do not overwrite an existing `.env` until you have reviewed its target. The file is ignored by
    Git and can contain machine-specific identifiers, but it must never contain a Databricks
    token, OAuth token, client secret, service-principal credential, private key, or the
    pseudonymization pepper. OAuth stays in CLI-managed user configuration outside the repository.

Review these dbt connection values in `.env`:

```text
DATABRICKS_HOST
DATABRICKS_HTTP_PATH
DBT_CONTROL_CATALOG
DBT_CONTROL_SCHEMA
DBT_PROJECT_CATALOG
DBT_SCHEMA_PREFIX
```

The checked-in `profiles.yml` reads them and uses `auth_type: oauth`.

Identity provisioning and persona acceptance additionally require the account, caller, warehouse,
and group fields documented in [Project configuration](../reference/configuration.md).

## Load the variables

```bash
set -a
source .env
set +a
```

This exports the values for dbt, Databricks Asset Bundles, and repository scripts in the
current shell. Repeat it in every new terminal session.

## Authenticate the CLI profile

```bash
databricks auth login \
  --host "$DATABRICKS_EXPECTED_HOST" \
  --profile "$DATABRICKS_CONFIG_PROFILE"
```

Confirm that the profile resolves successfully:

```bash
databricks auth describe \
  --profile "$DATABRICKS_CONFIG_PROFILE" \
  --output json
databricks current-user me \
  --profile "$DATABRICKS_CONFIG_PROFILE" >/dev/null
```

The first response should report successful authentication for the expected workspace host. The
second command proves the session can call the workspace API without printing the operator
identity. Do not paste authentication output into issues or workflow logs.

## Install and parse

```bash
uv sync --locked
uv run --locked dbt debug --profiles-dir .
uv run --locked dbt parse --profiles-dir .
```

`uv sync --locked` installs the pinned project and development environment. `dbt debug` proves the
local OAuth connection; `dbt parse` confirms that dbt can load the project and write local
artifacts.

!!! note
    `dbt parse` does not create the Unity Catalog catalog, secret, groups, or model relations.
    Complete [Deploy the demo for the first time](deploy-the-demo-for-the-first-time.md) for a new
    workspace.

Live OAuth and connectivity checks remain local. GitHub Actions deliberately performs only
credential-free offline validation; configure that boundary in
[Configure GitHub Actions validation](configure-github-actions.md).

Consult [Project configuration](../reference/configuration.md) for every environment variable,
storage boundary, and default.
