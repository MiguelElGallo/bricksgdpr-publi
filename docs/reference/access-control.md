---
title: Access control
icon: lucide/shield-check
---

# Access control

Access is defined by three fixed account-group names, dbt relation grants, parent privileges,
column masks, case-view predicates, and function revocations.

## Persona matrix

| Persona group | Layer1 source | Layer1 and quarantine | `priva_map` | Layer2 | Layer3 | Layer3 case | Internal UDF execution |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `privacy_admins` | Read | Read | Raw values | Read | Read | Read | None as a consumer grant |
| `restricted_users` | None | None | Read with raw columns masked to stored keys | Read | Read | None | None |
| `case_users` | None | None | None | None | Read | Selected readable values | None |

The deployment identity remains the privileged producer/owner and is not a consumer persona.

## Direct relation grants

| Schema | Relations | Grantees |
| --- | --- | --- |
| `layer1_source` | Five seeds | `privacy_admins` |
| `layer1` | Five staging views, three quarantine tables, two deletion-control tables | `privacy_admins` |
| `priva_map` | Two mapping tables | `privacy_admins`, `restricted_users` |
| `layer2` | Four protected tables | `privacy_admins`, `restricted_users` |
| `layer2` | Deletion plan and suppression-admission ledger | `privacy_admins` |
| `layer3` | Three dimensions, two facts | All three groups |
| `layer3_case` | Four case views | `privacy_admins`, `case_users` |

dbt relation `grants` configure `SELECT`. The singular access test compares the direct metadata to
this exact allowlist and rejects other relation privilege types.

## Parent privileges

All three groups receive `USE_CATALOG` on the project catalog. `USE_SCHEMA` follows the schemas
needed for their direct relation grants.

The expected direct parent privileges are:

- `privacy_admins`: all six data schemas;
- `restricted_users`: `priva_map`, `layer2`, and `layer3`;
- `case_users`: `layer3` and `layer3_case`.

No consumer group receives access to `priva_internal`.

## Mapping-mask behavior

| Caller | Raw mapping-column result |
| --- | --- |
| `privacy_admins` member | Raw value |
| `case_users` member | Raw value |
| Other caller, including `restricted_users` | Matching stored pseudonymous key |

`case_users` are raw-authorized inside the mask function but lack direct mapping-table grants. The
combination supports standard case views and makes the direct map grant a required security
boundary.

## Case-view predicate

`case_access_predicate()` accepts membership in either `case_users` or `privacy_admins`. It has no
row-specific input. Unaffiliated callers see zero rows; case users see every row exposed by each
view.

## Function boundary

The access operation revokes catalog execution, internal-schema privileges, and explicit execution
on all three functions from all persona groups. This prevents consumers from using the
pseudonymization function as a candidate-value oracle.

The secret scope is outside dbt access metadata. The repository does not validate the secret-scope
ACL; limiting it to the deployment identity is an operator invariant.

## Access operation

```text
apply_access_controls()
```

The macro applies expected parent-use grants and targeted revocations. It does not clear every
possible unexpected privilege on the six data schemas. The four access tests report missing or
extra direct metadata after the operation.

## Access tests

| Test | Metadata relation |
| --- | --- |
| `assert_access_relation_grants` | `system.information_schema.table_privileges` |
| `assert_access_parent_privileges` | Catalog and schema privilege information schemas |
| `assert_access_no_consumer_function_privileges` | `system.information_schema.routine_privileges` |
| `assert_access_no_ambient_grants` | Catalog, schema, relation, and routine privilege information schemas |

The ambient-grant test permits the three persona groups, `current_user()`, and the built-in
`account users` information-schema exceptions. It does not establish a complete account-wide proof
of transitive group membership.

## Identity boundary

Provisioning verifies direct persona-group separation, rejects account-admin/workspace-admin
states, and scans account group memberships. The implementation cannot prove every external or
future nested/effective entitlement. Persona SQL separately checks the runtime group vector.

For trust-boundary context, see
[Architecture and trust boundaries](../explanation/architecture-and-trust-boundaries.md).

**Sources:** `dbt_project.yml:29-73`, `macros/apply_access_controls.sql`,
`functions/mask_priva_map_value.sql`, `tests/assert_access_*.sql`,
`scripts/provision_identities.sh`.
