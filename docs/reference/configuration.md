---
title: Configuration
icon: lucide/settings
---

# Configuration

Configuration is split between environment variables, dbt variables, fixed security names, and
bundle deployment variables.

## Storage and trust boundaries

| Scope | Location | Allowed contents |
| --- | --- | --- |
| Public example | `.env.example` | Blank or reserved examples only |
| Local runtime | Ignored `.env` | Real tenancy/account identifiers and operator emails, never credentials or pepper material |
| Local authentication | CLI-managed user configuration | OAuth profile and session outside the repository |
| Trusted CI parsing | GitHub Actions repository secrets | Only `DATABRICKS_HOST` and `DATABRICKS_HTTP_PATH` |

All identity, acceptance, bundle, account, group, warehouse-ID, and email variables are local-only.
They must not become GitHub Actions secrets. Pull-request CI uses reserved placeholders and reads no
repository secret.

## dbt variables

| Variable | Default | Consumer | Contract |
| --- | --- | --- | --- |
| `schema_prefix` | Value of `DBT_SCHEMA_PREFIX`, otherwise empty | Schema-name macro and metadata tests | Prefixes the six data schemas; does not prefix `priva_internal` |
| `as_of_date` | `2026-03-01` | `int_invoices_resolved` and due-state test | An unpaid invoice is due when `due_date <= as_of_date` |
| `deletion_decision_as_of` | `9999-12-31 23:59:59` | Deletion-confirmation staging | Demo-only cutoff for reproducing an earlier decision state in an isolated schema |
| `deletion_policy_version` | `CUSTOMER_DELETION_V1` | Authorization gate and deletion plan | Only decision revisions carrying this implemented policy can authorize execution |
| `erased_member_key` | `-99999` | Layer2/Layer3 facts and special dimensions | Distinct non-person member replacing modeled customer/service foreign keys |
| `date_dimension_start` | `2025-01-01` | `dim_date` and dimension-count test | Inclusive first calendar date |
| `date_dimension_end` | `2028-12-31` | `dim_date` and dimension-count test | Inclusive last calendar date |
| `personal_data_hash_version` | `v1` | Versioned pseudonymization function | Fixed invariant; any other value raises a compiler error |
| `personal_data_secret_scope` | `bricksgdpr` | Versioned pseudonymization function | Fixed invariant; any other value raises a compiler error |
| `personal_data_secret_key` | `pepper_v1` | Versioned pseudonymization function | Fixed invariant; any other value raises a compiler error |

The `deletion_decision_as_of` cutoff is for deterministic walkthroughs and tests. It must not be
used to rewrite or bypass a production privacy decision history. A new deletion policy version
requires matching code and a new immutable decision revision; changing the variable alone does not
reinterpret an admitted ledger row. The three `personal_data_*`
entries are compile-time pins, not supported customization points.

**Source:** `dbt_project.yml`, `models/layer1/customer_deletion_authorization_history.sql`,
`functions/pseudonymize_personal_data_v1.sql`.

## Local dbt connection variables

| Environment variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `DATABRICKS_HOST` | Yes | None | Databricks workspace hostname used by the dbt adapter |
| `DATABRICKS_HTTP_PATH` | Yes | None | SQL warehouse HTTP path |
| `DBT_CONTROL_CATALOG` | No | `workspace` | Connection-default catalog |
| `DBT_CONTROL_SCHEMA` | No | `default` | Connection-default schema |
| `DBT_PROJECT_CATALOG` | No | `bricksgdpr` | Fallback analytical catalog; dbt `project_catalog` variable takes precedence |
| `DBT_EVIDENCE_CATALOG` | No | Analytical catalog + `_evidence` | Separate archive/events catalog; dbt `evidence_catalog` variable takes precedence |
| `DBT_SCHEMA_PREFIX` | No | Empty | Prefix applied to data schemas |

`DBT_CONTROL_CATALOG` and `DBT_CONTROL_SCHEMA` establish the adapter connection context. They do
not change the governed output catalog, which is set by `project_catalog` (dbt variable) or
`DBT_PROJECT_CATALOG` (environment fallback).

**Source:** `profiles.yml`, `dbt_project.yml:29-73`.

## GitHub Actions parsing variables

| Repository secret | Trusted events | Purpose |
| --- | --- | --- |
| `DATABRICKS_HOST` | Push to `main`; manual run on `main` | Renders the checked-in dbt profile |
| `DATABRICKS_HTTP_PATH` | Push to `main`; manual run on `main` | Renders the checked-in dbt profile |

Pull requests and manual runs from non-`main` refs use reserved placeholders instead. No CI path
authenticates or contacts Databricks during `dbt parse`; live assurance remains local and
OAuth-backed.

**Source:** `.github/workflows/ci.yml`.

## Identity and acceptance variables

| Environment variable | Provisioning | Persona validation | Contract |
| --- | --- | --- | --- |
| `DATABRICKS_CONFIG_PROFILE` | Required | Required | Explicit Databricks CLI profile |
| `DATABRICKS_WAREHOUSE_ID` | Required | Required | Exact warehouse ID; group permission must be direct `CAN_USE` |
| `DATABRICKS_ACCOUNT_ID` | Not used | Required | Exact account ID verified against authenticated configuration |
| `DATABRICKS_EXPECTED_HOST` | Required | Required | Exact `https://` workspace host |
| `DATABRICKS_EXPECTED_CALLER` | Required | Required | Expected authenticated operator email |
| `DATABRICKS_IDENTITY_MODE` | Required | Required | `synthetic` or `human` |
| `PRIVACY_ADMIN_EMAIL` | Required | Required | Persistent privacy-administrator identity |
| `RESTRICTED_USER_EMAIL` | Required | Required | Persistent restricted-user identity |
| `CASE_USER_EMAIL` | Required | Required | Persistent case-user identity |
| `PRIVACY_ADMIN_GROUP_ID` | Optional until groups exist | Required | Pinned `privacy_admins` account-group ID |
| `RESTRICTED_USER_GROUP_ID` | Optional until groups exist | Required | Pinned `restricted_users` account-group ID |
| `CASE_USER_GROUP_ID` | Optional until groups exist | Required | Pinned `case_users` account-group ID |

On a first account deployment, all three group-ID variables must be empty together. Existing
groups require their exact pinned IDs. Account-specific fields are intentionally blank in
`.env.example`; populate only the ignored `.env` copy.

Every variable in this section is local-only and forbidden from GitHub Actions secrets.

`.env.example` groups the values by consumer: shared provisioning/validation variables first,
validation-only `DATABRICKS_ACCOUNT_ID` second, and the three group IDs with their different
first-provisioning and validation requirements last.

**Source:** `.env.example`, `scripts/provision_identities.sh:10-24`,
`scripts/validate_personas.sh:10-21`.

## Bundle variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `warehouse_id` | None | SQL warehouse used by all bundle dbt tasks |
| `project_catalog` | Target-specific | Analytical catalog, passed as a dbt variable |
| `evidence_catalog` | Target-specific | Separate append-only evidence catalog |
| `control_catalog` | `workspace` | Existing connection-default catalog |
| `run_as_service_principal` | Empty | Required application ID for validation/prod |
| `failure_recipients` | `[]` | Email list for failure notifications; empty means disabled |

Sourcing `.env` exports `BUNDLE_VAR_warehouse_id` from the reviewed
`DATABRICKS_WAREHOUSE_ID`. Set `BUNDLE_VAR_control_catalog` if `workspace` is unavailable.
Bundle commands pass analytical/evidence catalogs as dbt variables, which take precedence over
environment fallbacks. See [Bundle job](bundle-job.md) and
[Deletion operations and recovery](deletion-operations.md).

**Source:** `databricks.yml:9-12`, `resources/bricksgdpr.job.yml:16-27`.

## Fixed names

| Name | Value | Status |
| --- | --- | --- |
| Privacy group | `privacy_admins` | Hardcoded security-contract name |
| Restricted group | `restricted_users` | Hardcoded security-contract name |
| Case group | `case_users` | Hardcoded security-contract name |
| Internal schema | `priva_internal` | Never schema-prefixed |
| Version-one wrapper | `pseudonymize_personal_data_v1` | Fixed function name |
| Version-one secret reference | `bricksgdpr/pepper_v1` | Fixed scope/key name |

The repository pins the secret reference, not the secret value. It does not inspect secret-scope
ACLs or prevent an operator from replacing `pepper_v1`; value immutability and ACL restriction are
operator-enforced invariants.

## Persona validation namespace

The model graph supports catalog variables and `DBT_SCHEMA_PREFIX`. The persona runner renders
`DBT_PROJECT_CATALOG` into its SQL templates after validating the identifier. It requires an empty
schema prefix.
