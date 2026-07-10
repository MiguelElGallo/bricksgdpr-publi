---
title: Functions and macros
icon: lucide/braces
---

# Functions and macros

The project defines three dbt-managed Databricks SQL functions and seven local Jinja macros.

## SQL functions

All functions are created in `<DBT_PROJECT_CATALOG>.priva_internal`.

### `hash_personal_data`

```text
hash_personal_data(
    canonical_value string,
    domain string,
    hash_version string,
    pepper string
) -> string
```

| Property | Contract |
| --- | --- |
| Null behavior | Null `canonical_value` returns null |
| Output | `<hash_version>:<sha256 digest>` |
| Digest input | Length-framed purpose marker, version, domain, canonical value, and pepper |
| Secret handling | Caller supplies `pepper`; consumer personas have no `EXECUTE` privilege |

**Sources:** `functions/hash_personal_data.sql`, `functions/_functions.yml:4-26`,
`macros/personal_data.sql:1-25`.

### `pseudonymize_personal_data_v1`

```text
pseudonymize_personal_data_v1(
    canonical_value string,
    domain string
) -> string
```

| Property | Contract |
| --- | --- |
| Version | Fixed `v1` |
| Secret reference | Fixed `secret('bricksgdpr', 'pepper_v1')` |
| Output | Same framed hash expression as `hash_personal_data` |
| Compile guard | Fails if any `personal_data_*` pin differs from the fixed v1 values |

The `secret()` call remains directly inside the SHA-256 expression. The wrapper does not retrieve
the secret value into Jinja or a model variable.

The function fixes the scope/key name only. The repository has no secret-value fingerprint,
secret-scope ACL test, or guard against overwriting `pepper_v1`. Pepper immutability and ACL
restriction are operator-enforced controls.

**Sources:** `functions/pseudonymize_personal_data_v1.sql`,
`functions/_functions.yml:28-45`.

### `mask_priva_map_value`

```text
mask_priva_map_value(
    raw_value string,
    pseudonymous_value string
) -> string
```

| Caller state | Return value |
| --- | --- |
| Member of `privacy_admins` | `raw_value` |
| Member of `case_users` | `raw_value` |
| Any other caller | `pseudonymous_value` |

The function does not calculate a key or read a secret at query time. Its second argument is the
stored key supplied through column-mask `USING COLUMNS` metadata.

**Sources:** `functions/mask_priva_map_value.sql`, `functions/_functions.yml:47-63`.

## Jinja macros

### `hash_personal_data_expression`

```jinja
hash_personal_data_expression(canonical_value, domain, hash_version, pepper)
```

Returns the null-preserving, length-framed SHA-256 SQL expression used by both hash functions.

### `canonicalize_personal_data`

```jinja
canonicalize_personal_data(value_expression, kind='text')
```

| `kind` | SQL canonicalization |
| --- | --- |
| `ssn` | Cast to string, trim, remove nondigits, empty to null |
| `phone` | Cast to string, trim, remove nondigits, empty to null |
| `date` | Cast to date and format `yyyy-MM-dd` |
| `text` or any other value | Cast to string, trim, lowercase, collapse whitespace, empty to null |

### `personal_data_key`

```jinja
personal_data_key(value_expression, domain, kind='text')
```

Canonicalizes the input and calls the dbt function reference for
`pseudonymize_personal_data_v1(canonical_value, domain)`.

**Source for all three:** `macros/personal_data.sql`.

### `case_access_predicate`

```jinja
case_access_predicate()
```

Returns a SQL Boolean expression that accepts membership in `case_users` or `privacy_admins`.
There is no subject-level or case-level input.

**Source:** `macros/case_access.sql`.

### `generate_schema_name`

```jinja
generate_schema_name(custom_schema_name, node)
```

| Condition | Result |
| --- | --- |
| No custom schema | `target.schema` |
| Function resource | Unprefixed custom schema |
| Nonempty `schema_prefix` | `<schema_prefix>_<custom_schema>` |
| Otherwise | Custom schema unchanged |

**Source:** `macros/generate_schema_name.sql`.

### `bootstrap_project_catalog`

```jinja
bootstrap_project_catalog()
```

When dbt is executing, runs `create catalog if not exists <DBT_PROJECT_CATALOG>`.

**Source:** `macros/bootstrap_project_catalog.sql`.

### `apply_access_controls`

```jinja
apply_access_controls()
```

When dbt is executing, this macro:

- grants `USE CATALOG` to the three persona groups;
- revokes catalog-level `SELECT` and `EXECUTE` from those groups;
- revokes all privileges on `priva_internal` and explicit execution on its three functions;
- grants the expected `USE SCHEMA` set per persona;
- revokes case access from source, Layer1, map, and Layer2 schema selection;
- revokes restricted access from the case schema and its four views;
- revokes case-user direct selection on both mapping tables.

The macro does not remove every possible unexpected schema privilege. The access data tests compare
the resulting direct metadata with the allowlist and report remaining differences.

**Source:** `macros/apply_access_controls.sql`.

For key construction properties, see
[Versioned, domain-separated keys](../explanation/versioned-domain-separated-keys.md).
