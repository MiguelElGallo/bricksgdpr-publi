---
title: Layer2
icon: lucide/shield
---

# Layer2

Layer2 replaces raw identity values with versioned pseudonymous keys, classifies nondeleted
records, and materializes accepted tables.

## Models

| Model | Materialization | Grain | Contract |
| --- | --- | --- | --- |
| `int_terminal_deleted_customer_keys` | Ephemeral | One key per historical SSN associated with a deleted customer ID | Expands terminal deletion before durable output |
| `int_customer_events_keyed` | Ephemeral | One source event | Replaces SSN with `customer_key` |
| `int_customer_event_resolution` | Ephemeral | One nondeleted source event | Assigns event resolution status |
| `int_customer_events_resolved` | Table | One accepted event | Contains customer key and event measures |
| `int_customer_protected` | Table | One active customer | Projects customer keys and nonidentity attributes from `fa_pd_customer` |
| `int_customer_services_keyed` | Ephemeral | One source service period | Replaces SSN, service ID, version tuple, and address with keys |
| `int_customer_service_resolution` | Ephemeral | One nondeleted service period | Assigns service resolution status |
| `int_customer_services_resolved` | Table | One accepted service period | Contains complete pseudonymous service tuple |
| `int_invoices_keyed` | Ephemeral | One source invoice | Replaces SSN and service ID with keys |
| `int_invoice_resolution` | Ephemeral | One nondeleted invoice | Resolves customer and effective service period, then validates dates/payment |
| `int_invoices_resolved` | Table | One accepted invoice | Contains resolved pseudonymous tuple and recomputed due state |

**Sources:** `models/layer2/*.sql`, `models/layer2/_layer2_*.yml`.

## Terminal-deletion key set

`int_terminal_deleted_customer_keys` uses every `stg_customer` row whose `customer_id` matches a
customer ID with at least one `DELETE`. Each historical SSN is canonicalized and pseudonymized in
the `customer.ssn` domain. Later upserts do not remove a customer from this set.

The model is ephemeral. Deleted keys are expanded into classifier queries and are not persisted as
a standalone relation.

## Event classifier

| Priority | Condition | `resolution_status` |
| ---: | --- | --- |
| Pre-filter | `customer_key` is terminally deleted | Record excluded from accepted and quarantine output |
| 1 | No matching `fa_pd_customer.customer_key` | `CUSTOMER_NOT_FOUND` |
| 2 | Customer exists | `ACCEPTED` |

**Source:** `models/layer2/int_customer_event_resolution.sql`.

## Service classifier

| Priority | Condition | `resolution_status` |
| ---: | --- | --- |
| Pre-filter | `customer_key` is terminally deleted | Record excluded from accepted and quarantine output |
| 1 | Customer map missing | `CUSTOMER_NOT_FOUND` |
| 2 | `is_valid = false` | `INVALID_VALIDITY_FLAG` |
| 3 | `valid_to < valid_from` | `INVALID_VALIDITY_PERIOD` |
| 4 | Complete customer/service/version/address tuple missing from `fa_pd_service_address` | `PRIVA_MAP_ENTRY_NOT_FOUND` |
| 5 | All controls pass | `ACCEPTED` |

**Source:** `models/layer2/int_customer_service_resolution.sql`.

## Invoice classifier

| Priority | Condition | `resolution_status` |
| ---: | --- | --- |
| Pre-filter | `customer_key` is terminally deleted | Record excluded from accepted and quarantine output |
| 1 | Customer map missing | `CUSTOMER_NOT_FOUND` |
| 2 | No source service period for `service_key` | `SERVICE_NOT_FOUND` |
| 3 | No service period for the invoice's customer | `CUSTOMER_SERVICE_MISMATCH` |
| 4 | No valid service period | `SERVICE_INVALID` |
| 5 | No valid period effective on `issued_date` | `SERVICE_NOT_VALID_ON_ISSUE_DATE` |
| 6 | More than one effective source period | `SERVICE_VERSION_AMBIGUOUS` |
| 7 | No accepted mapped effective period | `SERVICE_MAP_ENTRY_NOT_FOUND` |
| 8 | More than one accepted mapped effective period | `SERVICE_VERSION_AMBIGUOUS` |
| 9 | `due_date < issued_date` | `INVALID_INVOICE_DATE_RANGE` |
| 10 | Paid with null `paid_at` | `PAYMENT_DATE_MISSING` |
| 11 | Unpaid with nonnull `paid_at` | `PAYMENT_DATE_UNEXPECTED` |
| 12 | `paid_at < issued_date` | `PAYMENT_BEFORE_ISSUE_DATE` |
| 13 | All controls pass | `ACCEPTED` |

The priority order determines the single reported reason when more than one condition is invalid.

**Source:** `models/layer2/int_invoice_resolution.sql`.

## Accepted table columns

| Model | Columns |
| --- | --- |
| `int_customer_protected` | Ten customer keys, `customer_segment`, `is_active`, `source_updated_at` |
| `int_customer_events_resolved` | `event_id`, `customer_key`, `event_type`, `occurred_at`, `measure_value`, `measure_unit`, `source_updated_at` |
| `int_customer_services_resolved` | `customer_key`, `service_key`, `service_version_key`, `installation_address_key`, `service_type`, `is_valid`, `valid_from`, `valid_to`, `source_updated_at` |
| `int_invoices_resolved` | `invoice_id`, customer/service/version keys, amount/currency, issue/due/paid dates, `is_paid`, `source_is_due`, `is_due`, `source_updated_at` |

`is_due` is recomputed as `not is_paid and due_date <= as_of_date`. `source_is_due` preserves the
input value for comparison.

## Partition contract

For events, service periods, and invoices, every nondeleted keyed source row appears exactly once
across its accepted and quarantine relations. Terminally deleted rows appear in neither side.

The checked-in fixtures produce 28 accepted events, 16 accepted service periods, and 25 accepted
invoices.

## Assumptions and limits

- Customer linkage uses stable SSN-derived keys. Nondeleted SSN changes are not reconciled through
  an alias history.
- The protected tables contain no raw identity columns in the current SQL. The automated no-raw
  tests inspect a finite forbidden-name list and `_value` suffixes; they do not inspect arbitrary
  payload content.
- Event and invoice source IDs are retained. Their classification as nonidentifying transaction
  identifiers is a project assumption.

For classifier behavior, see
[Quarantine, not silent dropping](../explanation/quarantine-not-silent-dropping.md).
