---
icon: lucide/user-plus
---

# Provision persona identities

Use `scripts/provision_identities.sh` to create or reconcile the three account groups, their one
persistent user each, workspace `USER` assignments, group memberships, and warehouse `CAN USE`.

The script is read-only unless you pass `--apply`.

## Load and review the target

```bash
set -a
source .env
set +a
```

Confirm these values before continuing:

```text
DATABRICKS_CONFIG_PROFILE
DATABRICKS_WAREHOUSE_ID
DATABRICKS_EXPECTED_HOST
DATABRICKS_EXPECTED_CALLER
DATABRICKS_IDENTITY_MODE
PRIVACY_ADMIN_EMAIL
RESTRICTED_USER_EMAIL
CASE_USER_EMAIL
```

Existing groups also require their pinned `*_GROUP_ID` values.

For a genuinely new target where all three persona groups are absent, leave all three pinned group
IDs empty for the first apply. Do not clear only one or two IDs; the script rejects partial group
topology. Keep the pinned values when adopting the repository's configured demo groups.

!!! danger
    `--apply` changes account and workspace identity state. The expected caller must match the
    authenticated CLI user exactly.

## Choose the identity mode

For repository-owned topology fixtures:

```bash
export DATABRICKS_IDENTITY_MODE="synthetic"
export PRIVACY_ADMIN_EMAIL="bricksgdpr.privacy.admin@example.invalid"
export RESTRICTED_USER_EMAIL="bricksgdpr.restricted.user@example.invalid"
export CASE_USER_EMAIL="bricksgdpr.case.user@example.invalid"
```

Synthetic mode accepts only those three reserved addresses.

For real interactive acceptance, select human mode and provide three distinct deliverable or
IdP-backed addresses:

```bash
export DATABRICKS_IDENTITY_MODE="human"
export PRIVACY_ADMIN_EMAIL="<privacy-admin-email>"
export RESTRICTED_USER_EMAIL="<restricted-user-email>"
export CASE_USER_EMAIL="<case-user-email>"
```

Human mode rejects `example.invalid`. The script cannot prove that an address can authenticate;
verify each human session separately.

## Run the read-only preflight

```bash
scripts/provision_identities.sh --preflight-only
```

Read the plan. A new deployment should propose all three groups and users. An existing deployment
should resolve all three pinned groups and verify the current topology.

The script fails closed on partial group topology, unpinned name collisions, inactive or duplicate
users, cross-persona membership, admin privileges, unexpected group members, and direct user
warehouse permissions.

## Apply the plan

```bash
scripts/provision_identities.sh --apply
```

On success, each group has one `USER`-level workspace member and direct warehouse `CAN USE`. No
persona receives warehouse `CAN MANAGE`.

The script prints:

```text
PRIVACY_ADMIN_GROUP_ID=...
RESTRICTED_USER_GROUP_ID=...
CASE_USER_GROUP_ID=...
```

Store those IDs in the ignored `.env` file before the next run. They prevent the script from
silently adopting a same-named replacement group.

## Verify the final topology

```bash
scripts/provision_identities.sh --preflight-only
```

The final line should report that the read-only identity and Databricks target preflight passed
with no writes performed.

Provisioning does not prove data access. Continue with
[Reconcile access controls](reconcile-access-controls.md), then
[Validate persona access](validate-persona-access.md).

Consult [Identity and acceptance](../reference/identity-and-acceptance.md) for the exact input and
failure contract.
