---
title: priva_map
icon: lucide/key-round
---

# `priva_map`

`priva_map` is the separately governed schema that stores readable Personal Data beside its
pseudonymous equivalents.

## Relations

| Model | Materialization | Grain | Default rows |
| --- | --- | --- | ---: |
| `fa_pd_customer` | Table | One latest active customer with no matching authorized deletion plan | 15 |
| `fa_pd_service_address` | Table | One valid service period belonging to an active mapped customer | 17 |

The repository uses `fa_pd` for its full-access Personal Data mapping models.

## `fa_pd_customer`

### Selection contract

1. `UPSERT` rows are ranked by `customer_id`, newest `source_updated_at` and
   `customer_change_id` first.
2. The terminal ledger attaches the authorized mode to each historical customer key.
3. Both SPECIAL and FULL remove matching upserts from the mapping output.
4. Only rank-one active policy-eligible upserts remain.

An authorized delete is terminal even when a later upsert exists. A source tombstone with a
pending, invalid, rejected, or held decision does not enter the mapping exclusion gate.

### Columns

| State | Columns |
| --- | --- |
| Pseudonymized | `customer_key`, `customer_pk_key`, `customer_id_key`, `first_name_key`, `last_name_key`, `full_name_key`, `email_key`, `phone_key`, `birth_date_key`, `address_key` |
| Raw string | `customer_pk_value`, `customer_id_value`, `customer_ssn_value`, `first_name_value`, `last_name_value`, `full_name_value`, `email_value`, `phone_value`, `birth_date_value`, `address_value` |
| Other | `customer_segment`, `is_active`, `source_updated_at` |

Primary contract keys `customer_key`, `customer_pk_key`, and `customer_id_key` are individually
unique in the checked-in model tests.

**Sources:** `models/priva_map/fa_pd_customer.sql`, `models/priva_map/_priva_map.yml:4-186`.

## `fa_pd_service_address`

### Selection contract

Source service periods must satisfy all of the following:

- `is_valid = true`;
- `valid_to >= valid_from`;
- derived `customer_key` exists in `fa_pd_customer`.

### Columns

| State | Columns |
| --- | --- |
| Pseudonymized | `customer_key`, `service_key`, `service_version_key`, `installation_address_key` |
| Raw string | `service_id_value`, `customer_ssn_value`, `installation_address_value` |
| Other | `service_type`, `is_valid`, `valid_from`, `valid_to`, `source_updated_at` |

`service_version_key` is unique. `customer_key` has a relationship test to `fa_pd_customer`.

**Sources:** `models/priva_map/fa_pd_service_address.sql`,
`models/priva_map/_priva_map.yml:187-274`.

## Key domains

| Key | Input | Domain | Canonicalization |
| --- | --- | --- | --- |
| `customer_key` | SSN | `customer.ssn` | Digits only |
| `customer_pk_key` | Source numeric PK string | `customer.source_pk` | Lowercase, trim, collapse whitespace |
| `customer_id_key` | Source customer ID | `customer.id` | Lowercase, trim, collapse whitespace |
| `first_name_key` | First name | `customer.first_name` | Lowercase, trim, collapse whitespace |
| `last_name_key` | Last name | `customer.last_name` | Lowercase, trim, collapse whitespace |
| `full_name_key` | Composed full name | `customer.full_name` | Lowercase, trim, collapse whitespace |
| `email_key` | Email | `customer.email` | Lowercase, trim, collapse whitespace |
| `phone_key` | Phone | `customer.phone` | Digits only |
| `birth_date_key` | Birth date | `customer.birth_date` | ISO `YYYY-MM-DD` |
| `address_key` | Composed customer address | `customer.address` | Lowercase, trim, collapse whitespace |
| `service_key` | Source service ID | `service.id` | Lowercase, trim, collapse whitespace |
| `service_version_key` | `service_id|valid_from` | `service.version` | Lowercase, trim, collapse whitespace |
| `installation_address_key` | Composed installation address | `service.installation_address` | Lowercase, trim, collapse whitespace |

Equal canonical values in different domains produce different keys.

## Column masks

All masks use
`bricksgdpr.priva_internal.mask_priva_map_value(raw_value, pseudonymous_value)` by default.

| Relation | Raw column | `USING COLUMNS` value |
| --- | --- | --- |
| `fa_pd_customer` | `customer_pk_value` | `customer_pk_key` |
| `fa_pd_customer` | `customer_id_value` | `customer_id_key` |
| `fa_pd_customer` | `customer_ssn_value` | `customer_key` |
| `fa_pd_customer` | `first_name_value` | `first_name_key` |
| `fa_pd_customer` | `last_name_value` | `last_name_key` |
| `fa_pd_customer` | `full_name_value` | `full_name_key` |
| `fa_pd_customer` | `email_value` | `email_key` |
| `fa_pd_customer` | `phone_value` | `phone_key` |
| `fa_pd_customer` | `birth_date_value` | `birth_date_key` |
| `fa_pd_customer` | `address_value` | `address_key` |
| `fa_pd_service_address` | `service_id_value` | `service_key` |
| `fa_pd_service_address` | `customer_ssn_value` | `customer_key` |
| `fa_pd_service_address` | `installation_address_value` | `installation_address_key` |

The mask returns raw values to `privacy_admins` and `case_users`; all other callers receive the
stored pseudonymous value. `case_users` have no direct `priva_map` relation grant. That grant
boundary is required: if direct map access is added accidentally, the mask exposes every raw
column to a case-group member.

For the join behavior of stored masks, see
[Stored masks and joins](../explanation/stored-masks-and-joins.md).

## Classification metadata

The mapping YAML assigns two column tags to each listed Personal Data column:

- `personal_data_category`: `SOURCE_RECORD_IDENTIFIER`, `CUSTOMER_IDENTIFIER`,
  `NATIONAL_IDENTIFIER`, `NAME`, `EMAIL`, `PHONE`, `BIRTH_DATE`, `ADDRESS`, or
  `SERVICE_IDENTIFIER`;
- `personal_data_state`: `RAW` or `PSEUDONYMIZED`.

Both tables also carry `contains_personal_data=true` and `personal_data_area=priva_map`.

## Assumptions and limits

- The active-customer identity join assumes SSN is stable. A nondeleted customer changing SSN has
  no historical alias map; older dependent records resolve to the old key and can quarantine.
- `service_version_key` identifies `service_id + valid_from`. The project tests uniqueness of that
  pair but does not enforce nonoverlapping service periods.
- Pseudonymized values remain Personal Data. See
  [Personal Data is not anonymous](../explanation/personal-data-not-anonymous.md).
- The code fixes the scope/key name `bricksgdpr/pepper_v1`. It does not enforce the secret value's
  immutability or the secret-scope ACL; those are operator controls.
