---
title: Layer2
icon: lucide/shield
---

# Layer2

Layer2 replaces raw identity values with versioned pseudonymous keys, classifies records, and
reassigns retained event/invoice facts to the erased member after authorization.

## Models

| Model | Materialization | Grain | Contract |
| --- | --- | --- | --- |
| `int_customer_deletion_plan` | Incremental table | One row per authorized historical customer key and target relation | Auditable 17-target worklist retained across ordinary runs |
| `int_terminal_deleted_customer_keys` | Incremental table | One key per historical identity admitted by a complete authorized plan | Durable fail-closed deletion/reassignment gate |
| `int_customer_events_keyed` | Ephemeral | One source event | Replaces SSN with `customer_key` |
| `int_customer_event_resolution` | Ephemeral | One source event | Accepts erased facts or assigns ordinary resolution status |
| `int_customer_events_resolved` | Table | One accepted event | Contains customer/erased key, measures, and erasure flag |
| `int_customer_protected` | Table | One active customer | Projects customer keys and nonidentity attributes from `fa_pd_customer` |
| `int_customer_services_keyed` | Ephemeral | One source service period | Replaces SSN, service ID, version tuple, and address with keys |
| `int_customer_service_resolution` | Ephemeral | One nondeleted service period | Assigns service resolution status |
| `int_customer_services_resolved` | Table | One accepted service period | Contains complete pseudonymous service tuple |
| `int_invoices_keyed` | Ephemeral | One source invoice | Replaces SSN and service ID with keys |
| `int_invoice_resolution` | Ephemeral | One source invoice | Accepts erased facts or resolves and validates the ordinary tuple |
| `int_invoices_resolved` | Table | One accepted invoice | Contains resolved/erased tuple, due state, and erasure flag |

**Sources:** `models/layer2/*.sql`, `models/layer2/_layer2_*.yml`.

## Terminal-deletion key set

`int_terminal_deleted_customer_keys` contains every historical key for a detected request only
after its independent decision is authorized and its plan contains all 17 required targets. The
stable `customer_id` expands the request to every historical SSN, which is canonicalized and
pseudonymized in the `customer.ssn` domain. A source `DELETE` alone never enters this set, and later
upserts cannot restore a key retained by the incremental authorized plan.

The table retains the first admitting request and authorization/admission timestamps. Ordinary
incremental runs never remove an admitted key, even if later control input disappears or the target
inventory evolves. A deliberate `--full-refresh` can still rebuild this demo ledger.

Admission is not atomic completion evidence: downstream relations build afterward, and one may
fail while others succeed. The full build result and post-build tests are the demo's completion
evidence.

## Event classifier

| Priority | Condition | `resolution_status` |
| ---: | --- | --- |
| 1 | Customer is suppression-admitted | `ACCEPTED`; replace customer key with `-99999` |
| 2 | No matching `fa_pd_customer.customer_key` | `CUSTOMER_NOT_FOUND` |
| 3 | Customer exists | `ACCEPTED` |

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
| 1 | Non-erased customer map missing | `CUSTOMER_NOT_FOUND` |
| 2 | No source service period for `service_key` | `SERVICE_NOT_FOUND` |
| 3 | No service period for the invoice's customer | `CUSTOMER_SERVICE_MISMATCH` |
| 4 | No valid service period | `SERVICE_INVALID` |
| 5 | No valid period effective on `issued_date` | `SERVICE_NOT_VALID_ON_ISSUE_DATE` |
| 6 | More than one effective source period | `SERVICE_VERSION_AMBIGUOUS` |
| 7 | Non-erased invoice has no accepted mapped effective period | `SERVICE_MAP_ENTRY_NOT_FOUND` |
| 8 | Non-erased invoice has multiple accepted mapped periods | `SERVICE_VERSION_AMBIGUOUS` |
| 9 | `due_date < issued_date` | `INVALID_INVOICE_DATE_RANGE` |
| 10 | Paid with null `paid_at` | `PAYMENT_DATE_MISSING` |
| 11 | Unpaid with nonnull `paid_at` | `PAYMENT_DATE_UNEXPECTED` |
| 12 | `paid_at < issued_date` | `PAYMENT_BEFORE_ISSUE_DATE` |
| 13 | All controls pass | `ACCEPTED`; erased rows replace customer/service keys with `-99999` |

The priority order determines the single reported reason when more than one condition is invalid.

**Source:** `models/layer2/int_invoice_resolution.sql`.

## Accepted table columns

| Model | Columns |
| --- | --- |
| `int_customer_protected` | Ten customer keys, `customer_segment`, `is_active`, `source_updated_at` |
| `int_customer_events_resolved` | `event_id`, `customer_key`, event fields, `source_updated_at`, `is_erased_customer` |
| `int_customer_services_resolved` | `customer_key`, `service_key`, `service_version_key`, `installation_address_key`, `service_type`, `is_valid`, `valid_from`, `valid_to`, `source_updated_at` |
| `int_invoices_resolved` | `invoice_id`, customer/service/version keys, financial/date fields, due state, `source_updated_at`, `is_erased_customer` |

`is_due` is recomputed as `not is_paid and due_date <= as_of_date`. `source_is_due` preserves the
input value for comparison.

## Partition contract

Every event has one accepted or quarantine outcome. Every invoice has one accepted, quarantine, or
authorized-suppression outcome. Valid authorized-subject invoices remain accepted only after their
modeled keys are replaced; invalid authorized-subject invoices are not promoted and do not enter
raw quarantine. Service periods remain subject to current-row deletion because they are
identifying dimension-like records.

The checked-in fixtures produce 29 accepted events, 16 accepted service periods, and 26 accepted
invoices.

## Assumptions and limits

- Customer linkage uses stable SSN-derived keys. Nondeleted SSN changes are not reconciled through
  an alias history.
- The protected tables contain no raw identity columns in the current SQL. The automated no-raw
  tests inspect a finite forbidden-name list and `_value` suffixes; they do not inspect arbitrary
  payload content.
- Event and invoice source IDs are retained. Their classification as nonidentifying transaction
  identifiers is a project assumption.
- `-99999` removes modeled customer/service joins; it does not by itself prove that remaining
  timestamps, amounts, measures, or transaction IDs cannot single out a person.

For classifier behavior, see
[Quarantine, not silent dropping](../explanation/quarantine-not-silent-dropping.md).
