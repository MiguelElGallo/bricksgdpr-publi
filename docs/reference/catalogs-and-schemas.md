---
title: Catalogs and schemas
icon: lucide/database
---

# Catalogs and schemas

The deployment uses an analytical catalog with seven schemas and a separate evidence catalog
with a `deletion_control` schema. The connection-default catalog is configured independently.

## Catalogs

| Configuration | Default | Use |
| --- | --- | --- |
| `project_catalog` / `DBT_PROJECT_CATALOG` | `bricksgdpr` locally; target-specific in bundle | Analytical catalog; dbt variable takes precedence |
| `evidence_catalog` / `DBT_EVIDENCE_CATALOG` | Analytical name + `_evidence` | Separate append-only evidence; dbt variable takes precedence |
| `DBT_CONTROL_CATALOG` | `workspace` | Local dbt connection-default catalog |
| Bundle `control_catalog` | `workspace` | Run-scoped connection-default catalog for the job |

`bootstrap_project_catalog()` creates the analytical and evidence catalogs, the evidence schema,
and its two append-only tables. Analytical schemas are created by dbt as resources materialize.

## Schemas

| Logical schema | Default physical name | Contents | Default persona readers |
| --- | --- | --- | --- |
| Layer1 source | `layer1_source` | Five seed tables: four source extracts and the deletion-confirmation control | `privacy_admins` |
| Layer1 | `layer1` | Five staging views, three quarantine tables, and three deletion-control models | `privacy_admins` |
| Mapping | `priva_map` | Two raw-to-pseudonymous mapping tables | `privacy_admins`, `restricted_users` through masks |
| Layer2 protected | `layer2` | Four protected accepted tables | `privacy_admins`, `restricted_users` |
| Layer2 control | `layer2` | Deletion plan and terminal execution ledger | `privacy_admins` |
| Layer3 | `layer3` | Three dimensions and two facts | `privacy_admins`, `restricted_users` |
| Layer3 case | `layer3_case` | Four standard controlled readable views | `privacy_admins`, `case_users` |
| Internal | `priva_internal` | Three SQL functions | Deployment identity only |

The deployment identity remains a privileged catalog owner/producer and is outside the three
consumer-persona rows in the table.

## Schema prefix

For a nonempty `DBT_SCHEMA_PREFIX=<prefix>`, the six data schemas become:

```text
<prefix>_layer1_source
<prefix>_layer1
<prefix>_priva_map
<prefix>_layer2
<prefix>_layer3
<prefix>_layer3_case
```

`priva_internal` remains unchanged. Stable placement is required because column-mask metadata
stores a fully qualified function name.

Persona acceptance SQL does not follow prefixed schema names. It supports only the default names.

## Resource placement

| Resource class | Catalog rule | Schema rule |
| --- | --- | --- |
| Seeds | `project_catalog` variable, then `DBT_PROJECT_CATALOG` | `layer1_source`, with optional prefix |
| Models | `project_catalog` variable, then `DBT_PROJECT_CATALOG` | Folder-level schema, with optional prefix |
| Functions | `project_catalog` variable, then `DBT_PROJECT_CATALOG` | Fixed `priva_internal` |
| Evidence tables | `evidence_catalog` variable, then `DBT_EVIDENCE_CATALOG`, then analytical name + `_evidence` | Fixed `deletion_control` in separate catalog |
| Local dbt scratch/default context | `DBT_CONTROL_CATALOG` | `DBT_CONTROL_SCHEMA` |

## Parent privilege contract

| Persona | `USE CATALOG` | `USE SCHEMA` set |
| --- | --- | --- |
| `privacy_admins` | Project catalog | All six data schemas |
| `restricted_users` | Project catalog | `priva_map`, `layer2`, `layer3` |
| `case_users` | Project catalog | `layer3_case` |

Only direct parent privileges are compared by the dbt access tests. The exact effective-entitlement
boundary also depends on account-group nesting and caller metadata visibility.

**Sources:** `dbt_project.yml:29-73`, `macros/generate_schema_name.sql`,
`macros/apply_access_controls.sql`, `tests/assert_access_parent_privileges.sql`.

See [Deletion operations and recovery](deletion-operations.md) for durable control archives, execution states,
isolated private validation, and recovery rehearsal.
