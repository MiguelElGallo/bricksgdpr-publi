---
icon: lucide/trash-2
---

# Observe terminal deletion

In this tutorial, we will use the `CUST-0099` fixture to see how one deletion tombstone suppresses
every historical identity associated with a stable customer ID.

This is a lesson about logical current-state deletion. It is not proof that old bytes have been
removed from Delta history, caches, exports, or backups.

## Inspect the source history

Build from the checked-in fixtures, replacing current governed relations:

```bash
uv run dbt build --full-refresh --exclude tag:access_control
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
```

Now inspect the two source changes for `CUST-0099`:

```bash
uv run dbt show --inline "
select
    customer_change_id,
    customer_id,
    customer_ssn,
    source_operation,
    source_updated_at
from {{ ref('stg_customer') }}
where customer_id = 'CUST-0099'
order by source_updated_at
" --limit 10
```

You should see:

- an earlier `UPSERT` using `900-00-0199`; and
- a later `DELETE` tombstone using `900-00-0099`.

The SSNs differ. The stable `customer_id` is what lets the deletion control expand to both
historical identities.

## Observe the expanded deletion keys

The ephemeral `int_terminal_deleted_customer_keys` model contains both `v1` customer keys for
this subject:

```bash
uv run dbt show --inline "
with subject_ssns as (
    select distinct customer_ssn
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0099'
)
select deleted.customer_key
from {{ ref('int_terminal_deleted_customer_keys') }} as deleted
inner join subject_ssns as source
    on deleted.customer_key =
        {{ personal_data_key('source.customer_ssn', 'customer.ssn', 'ssn') }}
" --limit 10
```

The result contains two keys. The relation is ephemeral, so those keys guide the build without
becoming a durable deletion table.

## Check the governed outputs

Count matching rows in the main mapping and protected customer relations:

```bash
uv run dbt show --inline "
with subject_keys as (
    select distinct
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0099'
)
select 'fa_pd_customer' as relation_name, count(*) as remaining_rows
from {{ ref('fa_pd_customer') }}
where customer_key in (select customer_key from subject_keys)
union all
select 'int_customer_protected', count(*)
from {{ ref('int_customer_protected') }}
where customer_key in (select customer_key from subject_keys)
union all
select 'dim_customer', count(*)
from {{ ref('dim_customer') }}
where customer_key in (select customer_key from subject_keys)
" --limit 10
```

Every `remaining_rows` value should be `0`.

The same anti-join is applied to events, services, invoices, and raw quarantine outputs before
they are materialized.

## Run the deletion-control tests

```bash
uv run dbt test --select tag:deletion_control
```

In the trusted deployment or owner session, the passing map, Layer2, Layer3, and quarantine tests
return no violating rows. They do not by themselves prove what an authorized case user can see.

!!! warning
    An unaffiliated session sees zero case-view rows because the views fail closed. That zero-row
    result alone does not prove case-view deletion. Complete the separate aggregate check from an
    authorized case or privacy SQL session; follow
    [Verify terminal deletion](../how-to-guides/verify-terminal-deletion.md).

## What you have observed

Deletion wins over later or earlier upserts for the same stable customer ID. Rebuilding the demo's
full-replacement DAG removes the subject from current mapping, protected, quarantine, and case
outputs.

Next, [prove a protected-layer invariant](prove-a-protected-layer-invariant.md).

Read [Terminal deletion versus physical erasure](../explanation/terminal-deletion-vs-erasure.md)
before applying this pattern to production retention claims.
