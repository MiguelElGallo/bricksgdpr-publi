---
icon: lucide/triangle-alert
---

# Trace an invoice into quarantine

In this tutorial, we will follow `INV-0105`, a synthetic invoice that names a service which does
not exist. We will see the source row, its deterministic classification, and its quarantine row.

## Build the invoice path

The project tags invoice resolution as `layer2_invoices` and raw rejections as `quarantine`.
Include their upstream dependencies with the leading `+` selectors:

```bash
uv run dbt build --select "+tag:layer2 +tag:quarantine"
```

This builds the mapping and service inputs needed to classify invoices consistently.

## Inspect the source invoice

```bash
uv run dbt show --inline "
select
    invoice_id,
    customer_ssn,
    service_id,
    issued_date,
    due_date,
    is_paid
from {{ ref('stg_invoices') }}
where invoice_id = 'INV-0105'
" --limit 10
```

The row refers to `SVC-7777-A`. That service ID does not appear in the checked-in
`customer_services` seed.

## Ask the classifier for its decision

`int_invoice_resolution` is an ephemeral model. dbt expands it into the query rather than creating
a permanent relation.

```bash
uv run dbt show --inline "
select invoice_id, resolution_status
from {{ ref('int_invoice_resolution') }}
where invoice_id = 'INV-0105'
" --limit 10
```

The expected status is:

```text
SERVICE_NOT_FOUND
```

The classifier evaluates its rules in a fixed order. For this row, the customer exists, but no
source service period has the requested service key.

## Find the quarantine record

```bash
uv run dbt show --inline "
select
    invoice_id,
    service_id,
    quarantine_reason,
    quarantined_at
from {{ ref('quarantine_invoices') }}
where invoice_id = 'INV-0105'
" --limit 10
```

You should see one row with `quarantine_reason = SERVICE_NOT_FOUND`.

Now verify that the same invoice did not enter protected Layer2:

```bash
uv run dbt show --inline "
select count(*) as accepted_rows
from {{ ref('int_invoices_resolved') }}
where invoice_id = 'INV-0105'
" --limit 1
```

The result is `0`.

!!! note
    Quarantine is not a second copy of accepted data. Every non-deleted invoice is expected to
    appear exactly once: either in `int_invoices_resolved` or in `quarantine_invoices`.

## What you have observed

The source row was preserved, classified with a stable reason, excluded from protected analytics,
and made available for controlled remediation. It was not silently dropped.

Next, [observe terminal deletion](observe-terminal-deletion.md).

Read [Quarantine instead of silent dropping](../explanation/quarantine-not-silent-dropping.md)
for the design rationale. The exact Layer1 relations belong in the
[source and Layer1 reference](../reference/sources-and-layer1.md).
