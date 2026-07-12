---
icon: lucide/clipboard-check
---

# Customer deletion control

This page is the exact reference contract for customer-driven deletion. A `DELETE` change in the
customer source is the driver, but it is not sufficient by itself to remove downstream data.

## State machine

```mermaid
flowchart LR
    A["Customer source DELETE"] --> B["DETECTED<br/>persist request"]
    B --> C{"Independent decision"}
    C -->|"PENDING or REJECTED"| D["No plan<br/>no deletion authorization"]
    C -->|"Legal hold"| E["HELD<br/>no plan"]
    C -->|"CONFIRMED and no hold"| F["AUTHORIZED"]
    F --> G["Expand every historical customer identity"]
    G --> H["Create one plan row per key and target relation"]
    H --> I["Execution gate"]
    I --> J["Current governed outputs exclude the customer"]
```

The ordering is mandatory:

1. `stg_customer` detects a source row whose `source_operation` is `DELETE`.
2. `customer_deletion_requests` stores the request as `DETECTED`. It is incremental and keyed by
   `deletion_request_id`, so ordinary runs do not recreate or silently forget an existing request.
3. `customer_deletion_authorizations` joins a separate privacy decision. `CONFIRMED` authorizes
   work only when `legal_hold` is false. Missing decisions default to `PENDING`.
4. `int_customer_deletion_plan` exists only for `AUTHORIZED` requests. It expands the stable
   `customer_id` to every historical SSN, derives every customer key, and creates a row for every
   governed target.
5. `int_terminal_deleted_customer_keys` reads only authorized `DELETE_CURRENT_ROWS` plan rows.
   It admits a key only when all 17 required targets are present. Existing mapping, Layer2,
   quarantine, Layer3, and case models consume that execution gate.

There is no direct path from source tombstone to downstream anti-join.

## Control relations

| Relation | Materialization | Grain | Purpose |
| --- | --- | --- | --- |
| `stg_customer_deletion_confirmations` | View | One row per reviewed request | Types the independent decision input |
| `customer_deletion_requests` | Incremental table | One row per source `DELETE` change | Persists detection evidence |
| `customer_deletion_authorizations` | Table | One row per detected request | Applies confirmation and legal-hold gates |
| `int_customer_deletion_plan` | Incremental table | One row per authorized historical customer key and target | Retains exact planned coverage across ordinary runs |
| `int_terminal_deleted_customer_keys` | Incremental table | One row per admitted historical customer key | Durably records suppression admission and feeds every downstream anti-join |

The checked-in confirmation seed is a deterministic demo input. A production system should use a
separately authorized case-management or privacy-control source and an append-only audit trail.
A dbt `--full-refresh` can rebuild this demo's incremental ledger, so the ledger is not presented as
a production records-management system.

The authorization gate fails closed. A `CONFIRMED` decision becomes `INVALID`, not `AUTHORIZED`,
when its decision timestamp, reviewer role, reason, or legal-hold value is missing. The shared
target inventory drives plan creation, completeness checking, and the coverage test.

Suppression admission happens before downstream models run. dbt does not provide one atomic
transaction across all 17 targets, so the admission timestamp is not proof that every target
finished successfully. A successful build and post-build tests provide completion evidence for
this demo; production orchestration needs a separate completion/audit event.

## Decision and authorization values

| Input `decision_status` | `legal_hold` | Effective `authorization_status` | Plan created |
| --- | --- | --- | --- |
| Missing or `PENDING` | `false` | `PENDING` | No |
| `REJECTED` | `false` | `REJECTED` | No |
| `CONFIRMED` | `true` | `HELD` | No |
| `CONFIRMED` | `false` | `AUTHORIZED` | Yes |

Incomplete `CONFIRMED` input has effective status `INVALID` and creates no plan.

`CONFIRMED` means the privacy workflow has verified that this exact detected source request may
proceed. The demo does not decide whether Article 17 applies, verify a natural person's identity,
or adjudicate a legal exception; those are controller responsibilities outside dbt.

## Planned target coverage

For every historical customer key, the plan contains these 17 current-state targets:

| Area | Relations |
| --- | --- |
| Layer1 quarantine | `quarantine_customer_events`, `quarantine_customer_services`, `quarantine_invoices` |
| `priva_map` | `fa_pd_customer`, `fa_pd_service_address` |
| Layer2 | `int_customer_protected`, `int_customer_events_resolved`, `int_customer_services_resolved`, `int_invoices_resolved` |
| Layer3 | `dim_customer`, `dim_service`, `fct_customer_event`, `fct_invoice` |
| Controlled case views | `case_dim_customer`, `case_dim_service`, `case_fct_customer_event`, `case_fct_invoice` |

`assert_customer_deletion_control` fails if any target is missing or unexpected. The fixture
`CUST-0099` has two historical SSNs, so its confirmed request produces 34 plan rows: two keys times
17 targets.

Follow [Customer deletion: before and after](../tutorials/observe-terminal-deletion.md) to build the
real pre-confirmation and post-confirmation states and inspect every Layer3 table.

## Deliberately retained evidence

The source simulator and ordinary staging views retain source changes, including the deletion
tombstone and earlier upserts. The three deletion-control tables retain the minimum identifiers and
decision metadata needed to demonstrate detection, authorization, and planned coverage. These are
restricted Layer1 control records, not analytical outputs.

All other persisted Personal Data-bearing demo relations are in the plan. Staging/source retention
must have a documented purpose and retention period in production; the demo's reproducible CSV
fixtures are not a justification for indefinite production retention.

## Executed behavior versus physical erasure

The dbt build enforces logical current-state deletion: authorized keys disappear from current
tables and derived views. It does not prove removal from Delta history, deletion-vector files,
caches, exports, source systems, replicas, object versions, backups, or recipient systems.

For Delta tables with deletion vectors, Databricks documents a separate physical sequence:
`REORG TABLE ... APPLY (PURGE)` rewrites current files, then `VACUUM` removes expired historical
files. Upstream sources and downstream recipients must be handled separately.[^databricks-gdpr]
[^databricks-vacuum]

## GDPR control mapping

| Requirement | Design response | Remaining production obligation |
| --- | --- | --- |
| Article 5 storage limitation and accountability | Durable request state, explicit statuses, target inventory, executable tests | Define retention schedules and retain proportionate evidence |
| Article 12 response timing | Detection and decision timestamps make elapsed time measurable | Enforce the one-month response workflow and extension notices |
| Article 17 erasure and exceptions | Confirmation plus legal-hold gate prevents an unreviewed tombstone from self-authorizing | Verify identity, grounds, scope, and Article 17(3) exceptions |
| Article 19 recipient notification | Target list demonstrates internal propagation scope | Maintain recipient/disclosure inventory and notify recipients where required |
| Article 25 protection by design/default | No plan exists before confirmation; one gate controls all downstream models | Periodically test effectiveness and cover systems outside this repo |
| Article 30 processing records | Exact model, state, timestamp, and target fields support traceability | Maintain the controller's full record of processing activities |

The GDPR requires erasure without undue delay when Article 17 applies, while also defining
exceptions such as legal obligations and legal claims. It requires communication of erasure to
recipients under Article 19, accountability under Article 5, and safeguards by design and by
default under Article 25.[^gdpr-5][^gdpr-12][^gdpr-17][^gdpr-19][^gdpr-25][^gdpr-30]

This mapping is engineering guidance, not legal advice or a compliance certification.

## Implementation paths

- `seeds/customer_deletion_confirmations.csv`
- `models/layer1/stg_customer_deletion_confirmations.sql`
- `models/layer1/customer_deletion_requests.sql`
- `models/layer1/customer_deletion_authorizations.sql`
- `models/layer2/int_customer_deletion_plan.sql`
- `models/layer2/int_terminal_deleted_customer_keys.sql`
- `tests/assert_customer_deletion_control.sql`
- `tests/assert_unconfirmed_deletion_not_authorized.sql`

[^gdpr-5]: [GDPR Article 5 — principles and accountability](https://eur-lex.europa.eu/eli/reg/2016/679/art_5/oj/eng)
[^gdpr-12]: [GDPR Article 12 — action without undue delay and within one month](https://eur-lex.europa.eu/eli/reg/2016/679/art_12/oj/eng)
[^gdpr-17]: [GDPR Article 17 — right to erasure and exceptions](https://eur-lex.europa.eu/eli/reg/2016/679/art_17/oj/eng)
[^gdpr-19]: [GDPR Article 19 — notification to recipients](https://eur-lex.europa.eu/eli/reg/2016/679/art_19/oj/eng)
[^gdpr-25]: [GDPR Article 25 — data protection by design and by default](https://eur-lex.europa.eu/eli/reg/2016/679/art_25/oj/eng)
[^gdpr-30]: [GDPR Article 30 — records of processing activities](https://eur-lex.europa.eu/eli/reg/2016/679/art_30/oj/eng)
[^databricks-gdpr]: [Databricks — Prepare your data for GDPR compliance](https://docs.databricks.com/aws/en/ldp/gdpr)
[^databricks-vacuum]: [Databricks — Remove unused data files with VACUUM](https://docs.databricks.com/aws/en/delta/vacuum)
