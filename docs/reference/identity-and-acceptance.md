---
title: Identity and acceptance
icon: lucide/users
---

# Identity and acceptance

Identity provisioning manages persistent account users and groups. Persona acceptance uses
temporary service principals to test group-driven data-plane behavior.

## Fixed groups

| Group | Persistent user role |
| --- | --- |
| `privacy_admins` | Raw-area and controlled-case reader |
| `restricted_users` | Masked-map and protected-layer reader |
| `case_users` | Protected Layer3 and controlled-case reader |

Each group is an account group assigned to the workspace at `USER`. Each receives direct warehouse
`CAN_USE`, never `CAN_MANAGE`.

## Identity modes

| Mode | Accepted identities | User-record mutation |
| --- | --- | --- |
| `synthetic` | Exact repository-owned `example.invalid` addresses | Script-managed users with deterministic display-name markers; externally managed users rejected |
| `human` | Deliverable or IdP-backed nonreserved addresses | Existing externally managed users may be resolved but are not mutated |

### Synthetic identities

| Persona | Required email |
| --- | --- |
| Privacy administrator | `bricksgdpr.privacy.admin@example.invalid` |
| Restricted user | `bricksgdpr.restricted.user@example.invalid` |
| Case user | `bricksgdpr.case.user@example.invalid` |

Synthetic users establish persistent topology but cannot complete email verification. They do not
prove an interactive human login.

## Provisioning command modes

| Invocation | Mutation | Contract |
| --- | --- | --- |
| `scripts/provision_identities.sh` | None | Same as `--preflight-only` |
| `scripts/provision_identities.sh --preflight-only` | None | Verifies target, caller, warehouse, groups, users, memberships, and permissions; reports planned creation |
| `scripts/provision_identities.sh --apply` | Yes | Creates or reconciles only the allowed topology, then verifies it |

### Provisioned state

For each persona, apply mode establishes:

- one account group with a pinned ID;
- one distinct account user;
- group assignment to the workspace at `USER`;
- exactly one expected persistent group member;
- direct group warehouse permission `CAN_USE`;
- no direct user warehouse permission.

The script rejects partial group topology, unpinned existing groups, external group management,
cross-persona membership, account-admin roles, workspace-admin membership, and unexpected direct
members.

All three group IDs may be empty only when all three groups are absent. Account and group IDs are
deliberately blank in `.env.example`; exact values belong only in the ignored local `.env`.

## Persona SQL files

| Persona | Positive file | Denial files |
| --- | --- | --- |
| `privacy_admins` | `privacy_admin.sql` | `deny_udf.sql` |
| `restricted_users` | `restricted_user.sql` | `deny_layer1.sql`, `deny_quarantine.sql`, `deny_layer3_case.sql`, `deny_udf.sql` |
| `case_users` | `case_user.sql` | `deny_layer1.sql`, `deny_quarantine.sql`, `deny_layer2.sql`, `deny_priva_map.sql`, `deny_udf.sql` |

Positive files assert the exact `session_user()`, a mutually exclusive persona-group vector,
non-admin state, and aggregate access properties. They do not return readable Personal Data.

Negative files each contain one prohibited query.

**Source:** `acceptance/personas/`.

## Task-state contract

| Task class | Required result |
| --- | --- |
| Positive task | `SUCCESS` |
| Every denial task | `FAILED` |
| Denial error class | Contains `INSUFFICIENT_PERMISSIONS` |
| Denial SQL state | Contains `SQLSTATE: 42501` |

A parse, missing-object, compute, timeout, or internal error is not an authorization pass. Each
persona run contains independent tasks; its parent run is expected to be failed because denial
tasks fail intentionally.

## Temporary-principal runner

`scripts/validate_personas.sh --apply` creates one service principal per persona, assigns it to the
workspace at `USER`, adds it to exactly one persona group, grants the operator the Run-as role,
uploads the SQL files, submits one one-time run per persona, validates exact task outcomes, and
cleans up.

The runner creates no service-principal credential. Cleanup deactivates and deletes temporary
principals, removes group memberships and workspace files, and handles submitted runs. A cleanup
failure exits with status `90` and identifies the resources for inspection. Bounded retries and
consecutive absence observations prevent an eventually consistent SCIM or workspace read from
being mistaken for either a leak or successful cleanup. Each absence check allows up to 10
observations at two-second intervals and requires two consecutive absent observations.

## Namespace restriction

Persona SQL contains literal `bricksgdpr.layer1`, `bricksgdpr.priva_map`, `bricksgdpr.layer2`,
`bricksgdpr.layer3`, `bricksgdpr.layer3_case`, and `bricksgdpr.priva_internal` names. The runner
does not substitute the catalog or schema prefix.

Persona validation therefore supports only:

| Setting | Required value |
| --- | --- |
| `DBT_PROJECT_CATALOG` | `bricksgdpr` |
| `DBT_SCHEMA_PREFIX` | Empty |

## Acceptance limits

- Temporary service-principal runs prove group-driven SQL behavior, not human email verification
  or interactive login.
- Human-mode address deliverability is an operator attestation until each user authenticates
  separately.
- Positive case SQL uses uniqueness assertions suitable for the synthetic fixtures; duplicate real
  names or addresses would require a different assertion.
- Provisioning and SQL checks do not prove every transitive entitlement outside the inspected
  account/group state.

**Sources:** `scripts/provision_identities.sh`, `scripts/validate_personas.sh`,
`acceptance/personas/README.md`.
