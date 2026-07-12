---
title: Catalogs and schemas
icon: lucide/database
---

# Catalogs and schemas

The default deployment uses one governed catalog and seven schemas.

## Catalogs

| Configuration | Default | Use |
| --- | --- | --- |
| `DBT_PROJECT_CATALOG` | `bricksgdpr` | Database/catalog for all project seeds, functions, and models |
| `DBT_CONTROL_CATALOG` | `workspace` | Local dbt connection-default catalog |
| Bundle dbt task `catalog` | `workspace` | Run-scoped connection-default catalog for the job |

`bootstrap_project_catalog()` creates only the governed project catalog. Schemas are created by dbt
as resources are materialized.

## Schemas

| Logical schema | Default physical name | Contents | Default persona readers |
| --- | --- | --- | --- |
| Layer1 source | `layer1_source` | Four seed tables | `privacy_admins` |
| Layer1 | `layer1` | Four staging views and three quarantine tables | `privacy_admins` |
| Mapping | `priva_map` | Two raw-to-pseudonymous mapping tables | `privacy_admins`, `restricted_users` through masks |
| Layer2 | `layer2` | Four protected accepted tables | `privacy_admins`, `restricted_users` |
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
| Seeds | `DBT_PROJECT_CATALOG` | `layer1_source`, with optional prefix |
| Models | `DBT_PROJECT_CATALOG` | Folder-level schema, with optional prefix |
| Functions | `DBT_PROJECT_CATALOG` | Fixed `priva_internal` |
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
