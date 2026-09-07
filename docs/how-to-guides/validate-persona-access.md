---
icon: lucide/users
---

# Validate persona access

Use `scripts/validate_personas.sh` to prove the group-driven data plane without retaining
credentials or temporary principals.

The script creates one temporary service principal per persona, submits isolated SQL file tasks,
checks the exact outcomes, and removes every temporary resource.

## Prerequisites

Before running the validator:

1. complete [Provision persona identities](provision-persona-identities.md);
2. complete [Reconcile access controls](reconcile-access-controls.md);
3. set every account, workspace, warehouse, caller, persona, and pinned group variable in `.env`;
4. ensure `databricks`, `jq`, and `uuidgen` are available.

!!! warning
    The runner renders catalog-qualified SQL from the templates using `DBT_PROJECT_CATALOG`.
    The catalog must match `[a-z][a-z0-9_]*` and `DBT_SCHEMA_PREFIX` must be empty.

Load the variables:

```bash
set -a
source .env
set +a
```

Confirm the reviewed catalog and unprefixed schema layout before continuing:

```bash
test -n "$DBT_PROJECT_CATALOG"
test -z "$DBT_SCHEMA_PREFIX"
```

Both commands must exit successfully.

Run the identity preflight first:

```bash
scripts/provision_identities.sh --preflight-only
```

## Run the acceptance workflow

```bash
scripts/validate_personas.sh --apply
```

!!! danger
    This command creates and deletes three temporary Databricks service principals, one-time Job
    runs, and a temporary workspace directory. Run it only against the reviewed account and
    workspace.

The positive task for each persona must succeed. Every prohibited task must fail with both
`INSUFFICIENT_PERMISSIONS` and SQLSTATE `42501`.

Expected progress includes:

```text
PASS privacy: positive task succeeded and every denial returned SQLSTATE 42501.
PASS restricted: positive task succeeded and every denial returned SQLSTATE 42501.
PASS case: positive task succeeded and every denial returned SQLSTATE 42501.
Persona acceptance passed and all temporary principals and workspace files were removed.
```

!!! note
    The parent Job run can look failed because its negative tasks are expected to fail. The script,
    not the parent badge alone, decides acceptance by checking every task and error code.

## Confirm cleanup

The script deactivates and deletes each temporary principal, removes it from its persona group,
deletes uploaded SQL files, and reruns the identity preflight. If cleanup cannot be verified, the
script exits with status `90` and names the resources that require immediate inspection.

Databricks account SCIM and workspace reads can be eventually consistent. Cleanup therefore
retries removal and requires consecutive absence observations for principal IDs, display names,
group memberships, and workspace files before reporting success.

The workflow creates no client secret or retained credential.

Consult [Identity and acceptance](../reference/identity-and-acceptance.md) for the positive/negative
matrix and [Executable security controls](../explanation/executable-security-controls.md) for the
assurance model.
