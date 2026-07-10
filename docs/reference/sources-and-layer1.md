---
title: Sources and Layer1
icon: lucide/layers-3
---

# Sources and Layer1

Layer1 consists of four deterministic seed tables, four typed staging views, and three raw
quarantine tables. The project defines no dbt `source` resources.

## Seeds

| Seed | Rows | Grain | Direct Personal Data |
| --- | ---: | --- | --- |
| `customer` | 19 | One source customer change | Source customer identifiers, SSN, name, email, phone, birth date, and customer address |
| `customer_events` | 30 | One measured customer event | SSN |
| `customer_services` | 20 | One service identifier and validity interval | SSN and installation address |
| `invoices` | 37 | One invoice | SSN and source service reference |

All seed columns are loaded as strings according to `seeds/_seeds.yml`. Staging models apply the
warehouse types.

**Sources:** `seeds/*.csv`, `seeds/_seeds.yml`, `scripts/generate_seeds.py`.

## Seed fixtures

| Fixture | Identifier | Expected current behavior |
| --- | --- | --- |
| Active customers | `CUST-0001` through `CUST-0014` | Fourteen current customer-map rows |
| Inactive customer | `CUST-0015` | Excluded from the customer map |
| Delete followed by later upsert | `CUST-0097` | Remains terminally deleted |
| Changed SSN followed by delete | `CUST-0099` | Both current and historical SSN keys are deleted |
| Late customer references | SSN ending `0098` | Event, service, and invoice quarantine as `CUSTOMER_NOT_FOUND` |
| Invalid service flag | `SVC-0013-B` | Quarantines as `INVALID_VALIDITY_FLAG` |
| Invalid service period | `SVC-0014-A` | Quarantines as `INVALID_VALIDITY_PERIOD` |
| Invoice control records | `INV-0101` through `INV-0107` | Exercise payment, date, customer/service, missing-service, and service-period rules |

Exact IDs and counts are demonstration fixtures, not production data-quality thresholds.

## Staging models

| Model | Materialization | Grain | Normalization |
| --- | --- | --- | --- |
| `stg_customer` | View | One source change record | Trims strings; uppercases operation/country; casts PK, date, Boolean, and timestamp values; converts empty optional values to null |
| `stg_customer_events` | View | One event | Trims IDs; uppercases event type/unit; casts timestamp and decimal measure |
| `stg_customer_services` | View | One service validity interval | Trims IDs/address; uppercases type/country; casts Boolean, dates, and timestamp |
| `stg_invoices` | View | One invoice | Trims IDs; uppercases currency; casts amount, dates, Booleans, and timestamp |

Staging preserves source grain and does not resolve customer or service relationships.

**Sources:** `models/layer1/stg_customer.sql`, `stg_customer_events.sql`,
`stg_customer_services.sql`, `stg_invoices.sql`.

## Staging columns

| Model | Columns |
| --- | --- |
| `stg_customer` | `customer_change_id`, `customer_pk`, `customer_id`, `customer_ssn`, `first_name`, `last_name`, `email`, `phone`, `birth_date`, `address_line1`, `address_line2`, `city`, `postal_code`, `country_code`, `customer_segment`, `is_active`, `source_operation`, `source_updated_at` |
| `stg_customer_events` | `event_id`, `customer_ssn`, `event_type`, `occurred_at`, `measure_value`, `measure_unit`, `source_updated_at` |
| `stg_customer_services` | `service_id`, `customer_ssn`, `service_type`, five installation-address components, `is_valid`, `valid_from`, `valid_to`, `source_updated_at` |
| `stg_invoices` | `invoice_id`, `customer_ssn`, `service_id`, `amount`, `currency_code`, `issued_date`, `due_date`, `is_paid`, `paid_at`, `is_due`, `source_updated_at` |

## Quarantine models

| Model | Materialization | Grain | Raw identifier | Reason source |
| --- | --- | --- | --- | --- |
| `quarantine_customer_events` | Table | One rejected nondeleted event | `event_id` | `int_customer_event_resolution` |
| `quarantine_customer_services` | Table | One rejected or invalid nondeleted service period | `service_id`, `valid_from` | `int_customer_service_resolution` |
| `quarantine_invoices` | Table | One rejected or invalid nondeleted invoice | `invoice_id` | `int_invoice_resolution` |

Each quarantine table contains source-shaped raw values, `quarantine_reason`, and a build-time
`quarantined_at` timestamp. The tables are fully replaced on rebuild. A record leaves quarantine
when the same keyed source row becomes resolvable.

### Quarantine reason values

| Stream | Accepted `quarantine_reason` values |
| --- | --- |
| Events | `CUSTOMER_NOT_FOUND` |
| Services | `CUSTOMER_NOT_FOUND`, `INVALID_VALIDITY_FLAG`, `INVALID_VALIDITY_PERIOD`, `PRIVA_MAP_ENTRY_NOT_FOUND` |
| Invoices | `CUSTOMER_NOT_FOUND`, `SERVICE_NOT_FOUND`, `CUSTOMER_SERVICE_MISMATCH`, `SERVICE_INVALID`, `SERVICE_NOT_VALID_ON_ISSUE_DATE`, `SERVICE_VERSION_AMBIGUOUS`, `SERVICE_MAP_ENTRY_NOT_FOUND`, `INVALID_INVOICE_DATE_RANGE`, `PAYMENT_DATE_MISSING`, `PAYMENT_DATE_UNEXPECTED`, `PAYMENT_BEFORE_ISSUE_DATE` |

**Sources:** `models/layer1/quarantine_*.sql`, `models/layer1/_layer1.yml`.

## Default output counts

| Stream | Accepted | Quarantine | Terminal-deletion exclusion | Seed total |
| --- | ---: | ---: | ---: | ---: |
| Events | 28 | 1 | 1 | 30 |
| Service periods | 16 | 3 | 1 | 20 |
| Invoices | 25 | 11 | 1 | 37 |

## Deletion scope

Terminal deletion removes current rows from `priva_map`, Layer2, Layer3, quarantine, and case
outputs. It does not remove the demonstration source records from seeds or ordinary staging views.
`stg_customer` intentionally retains upserts and tombstones so the deletion contract is
reproducible.

For the difference between logical output deletion and physical erasure, see
[Terminal deletion versus erasure](../explanation/terminal-deletion-vs-erasure.md).
