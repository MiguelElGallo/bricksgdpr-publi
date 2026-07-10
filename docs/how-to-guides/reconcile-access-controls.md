---
icon: lucide/shield-check
---

# Reconcile access controls

Use this guide after relations have been created or changed, or when live Unity Catalog grants may
have drifted from the repository's exact allowlist.

## Prerequisites

The three account groups—`privacy_admins`, `restricted_users`, and `case_users`—must exist. Load the
same target variables that were used to build the relations.

```bash
set -a
source .env
set +a
```

## Reconcile relation grants

```bash
uv run dbt build --exclude tag:access_control
```

The model and seed `grants` configurations reconcile relation-level `SELECT` privileges while the
build creates and tests the governed relations.

## Reconcile parent privileges and revocations

```bash
uv run dbt run-operation apply_access_controls
```

The operation grants only the required `USE CATALOG` and `USE SCHEMA` privileges. It also revokes
broad catalog access, consumer access to `priva_internal`, direct case-user access to `priva_map`,
restricted-user access to case views, and consumer UDF execution.

!!! warning
    This operation changes live privileges. Confirm `DBT_PROJECT_CATALOG` and
    `DBT_SCHEMA_PREFIX` before running it.

## Test the exact allowlist

```bash
uv run dbt test --select tag:access_control
```

Four singular tests should pass. They reject:

- missing or extra relation grants;
- non-`SELECT` relation privileges;
- missing or unexpected parent privileges;
- ambient governed-object grants; and
- any consumer privilege on an internal function.

Do not fix a failure by adding a broader grant. Identify whether the live metadata or the declared
contract is wrong, correct that source, and rerun the complete sequence.

!!! warning "Detection is broader than remediation"
    `apply_access_controls` is not a universal cleanup operation. The tests can detect extra
    data-schema or relation privileges that the macro does not revoke. Remove those privileges
    through the approved least-privilege operator process, then rerun the operation and all four
    tests.

Consult the [access-control reference](../reference/access-control.md) for the exact matrix and
[Executable security controls](../explanation/executable-security-controls.md) for why denial tests
are part of the deployment contract.
