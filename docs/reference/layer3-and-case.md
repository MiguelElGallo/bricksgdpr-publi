---
title: Layer3 and case views
icon: lucide/chart-no-axes-combined
---

# Layer3 and case views

Layer3 contains protected dimensions and facts. `layer3_case` contains standard views that resolve
a fixed subset of readable values.

## Layer3 dimensions

| Model | Materialization | Grain | Primary contract key |
| --- | --- | --- | --- |
| `dim_customer` | Table | One active pseudonymous customer plus erased member | `customer_key` |
| `dim_service` | Table | One accepted service validity period plus erased member | `service_version_key` |
| `dim_date` | Table | One calendar day in the configured inclusive range | `date_key` |

### `dim_customer`

`dim_customer` contains the Type-1 current projection of `int_customer_protected` plus the
non-natural-person `ERASED_SUBJECT` row. Its customer and attribute keys are `-99999`, it is
inactive, and it has no `priva_map` entry.

### `dim_service`

`dim_service` is Type-2-style, not a complete SCD Type 2 implementation. A version is identified by
the pseudonymized `service_id + valid_from` tuple. The project enforces tuple uniqueness but does
not manage current-row flags, period gaps, or period overlap. The erased service member uses
`-99999` for customer, service, version, and address keys so retained invoice facts still resolve.

Columns are `customer_key`, `service_key`, `service_version_key`,
`installation_address_key`, `service_type`, `is_valid`, `valid_from`, `valid_to`, and
`source_updated_at`.

### `dim_date`

| Property | Value |
| --- | --- |
| Default range | `2025-01-01` through `2028-12-31`, inclusive |
| Default rows | 1,461 |
| Key | Integer `YYYYMMDD` |
| Attributes | Date, year, quarter, month number/name, day number/name, day of week, week number, weekend flag |

Fact relationship tests require referenced dates to exist inside this range. Source dates outside
the configured interval fail those tests unless the date range is expanded.

**Sources:** `models/layer3/dim_*.sql`, `models/layer3/_layer3_dimensions.yml`.

## Layer3 facts

| Model | Materialization | Grain | Key | Dimension links |
| --- | --- | --- | --- | --- |
| `fct_customer_event` | Table | One accepted event | `event_key` from source `event_id` | Customer and event date |
| `fct_invoice` | Table | One accepted invoice | `invoice_key` from source `invoice_id` | Customer, service version, issue date, due date, optional paid date |

### `fct_customer_event` columns

`event_key`, `customer_key`, `event_date_key`, `occurred_at`, `event_type`, `measure_value`,
`measure_unit`, `source_updated_at`, `is_erased_customer`.

### `fct_invoice` columns

`invoice_key`, `customer_key`, `service_key`, `service_version_key`, `issue_date_key`,
`due_date_key`, `paid_date_key`, `amount`, `currency_code`, `is_paid`, `source_is_due`, `is_due`,
`source_updated_at`, `is_erased_customer`.

Facts derive integer date keys but do not directly `ref('dim_date')`; generic relationship tests
enforce the date links.

The project assumes source event IDs and invoice IDs are transaction identifiers that can be
retained as fact keys. Deployments where those values are identifying require a different
classification and key design.

**Sources:** `models/layer3/fct_*.sql`, `models/layer3/_layer3_facts.yml`.

## Case views

| View | Protected parent grain | Additional readable columns |
| --- | --- | --- |
| `case_dim_customer` | One customer | `customer_id`, `full_name`, `email`, `customer_address` |
| `case_dim_service` | One service validity period | `service_id`, `installation_address` |
| `case_fct_customer_event` | One event | `full_name`, `email` |
| `case_fct_invoice` | One invoice | `full_name`, `email`, `service_id`, `installation_address` |

Each view preserves the keys needed to prove its join to protected parents and mapping rows. Joins
use complete stored pseudonymous tuples; they do not use masked raw columns.

All four objects are standard views and end with `case_access_predicate()`. The predicate returns
true for `case_users` or `privacy_admins`; an unaffiliated caller receives zero rows.

## Case-access boundary

Case access is group-wide. The project has no case ID, subject-specific row allowlist, approval
record, expiration, or per-query audit artifact. Every member of `case_users` can resolve every row
exposed by the four case views.

Case users have no direct `priva_map` grant. The mapping mask nevertheless treats `case_users` as
raw readers so the standard views can resolve values. Exact relation grants are therefore part of
the case-view security contract.

For the boundary and production gaps, see
[Case views and least privilege](../explanation/case-views-and-least-privilege.md).

## Deletion behavior

Deleted customer keys are absent from every Layer3 relation and all case views. Under
`SPECIAL_DELETION`, real customer/service dimensions disappear while event and invoice facts retain
their grain under `-99999`, set `is_erased_customer = true`, and are excluded from case views. Under
`FULL_GOVERNED_OUTPUT_DELETION`, the subject's event and invoice facts are also absent. `dim_date`
has no customer key and is unchanged under both modes.

The erased-member pattern follows Kimball's recommendation to use descriptive special dimension
records instead of null fact foreign keys. It is a referential-integrity technique, not proof of
GDPR anonymisation; remaining fact attributes require a separate identifiability assessment.

The guided [Layer3 before-and-after deletion tutorial](../tutorials/observe-terminal-deletion.md)
shows the exact fixture rows and totals in all five tables on both sides of authorization.

The case-view deletion dbt test reads the restricted incremental execution ledger and calls
the protected pseudonymization function. Ordinary case and privacy persona identities cannot
execute that complete singular-test query. Deletion evidence therefore combines owner-side dbt
tests for the protected outputs with a separate aggregate query, executed as an authorized case or
privacy identity, against the case views.
