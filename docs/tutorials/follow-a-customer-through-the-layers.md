---
icon: lucide/route
---

# Follow a customer through the layers

In this tutorial, we will follow the fictional customer `CUST-0001` from a readable Layer1 record
to a protected Layer3 dimension.

Along the way, notice that the business facts remain useful while direct identifiers become
stable, versioned keys.

## Before you begin

Complete [Build and explore the demo](build-and-explore-the-demo.md). Run this lesson
as the deployment identity, because it needs to call the internal pseudonymization wrapper while
resolving the tutorial's fixed customer key.

## Start with the source-shaped record

Layer1 casts the CSV values to useful types but deliberately keeps the source shape and readable
Personal Data.

```bash
uv run dbt show --inline "
select
    customer_id,
    customer_ssn,
    first_name,
    email,
    customer_segment,
    source_operation
from {{ ref('stg_customer') }}
where customer_id = 'CUST-0001'
" --limit 10
```

You should see one `UPSERT` for `CUST-0001`, with the synthetic SSN `900-00-0001` and the email
`customer01@example.invalid`.

!!! note
    Layer1 is a governed raw area. Keeping readable source values here is intentional; general
    analytical consumers cannot read it.

## Find the pseudonymous mapping

The `personal_data_key` macro canonicalizes a value and calls the fixed `v1` wrapper in the
`priva_internal` schema. Use it to locate the mapping without depending on a masked raw column:

```bash
uv run dbt show --inline "
with tutorial_customer as (
    select customer_ssn
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0001' and source_operation = 'UPSERT'
)
select
    mapped.customer_key,
    mapped.customer_id_key,
    mapped.full_name_key,
    mapped.email_key,
    mapped.customer_segment
from {{ ref('fa_pd_customer') }} as mapped
inner join tutorial_customer as source
    on mapped.customer_key =
        {{ personal_data_key('source.customer_ssn', 'customer.ssn', 'ssn') }}
" --limit 10
```

The key columns begin with `v1:`. They are not interchangeable: the same input in a different
domain, such as `customer.ssn` or `customer.email`, produces a different key.

The mapping table also contains readable values, protected by Unity Catalog column masks. We do
not use those masked columns for joins.

## Move into protected Layer2

Layer2 projects the mapping into an analytical customer relation containing pseudonymous keys and
non-identifying business attributes:

```bash
uv run dbt show --inline "
with tutorial_customer as (
    select customer_ssn
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0001' and source_operation = 'UPSERT'
)
select
    protected.customer_key,
    protected.customer_id_key,
    protected.full_name_key,
    protected.email_key,
    protected.customer_segment,
    protected.is_active
from {{ ref('int_customer_protected') }} as protected
inner join tutorial_customer as source
    on protected.customer_key =
        {{ personal_data_key('source.customer_ssn', 'customer.ssn', 'ssn') }}
" --limit 10
```

Compare this result with Layer1. The segment and active state remain directly useful. The SSN,
customer ID, name, and email no longer appear as readable values.

## Arrive in the Layer3 dimension

The current customer dimension preserves the protected customer grain: one row per active
pseudonymous customer.

```bash
uv run dbt show --inline "
with tutorial_customer as (
    select customer_ssn
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0001' and source_operation = 'UPSERT'
)
select
    customers.customer_key,
    customers.customer_id_key,
    customers.full_name_key,
    customers.email_key,
    customers.customer_segment,
    customers.is_active
from {{ ref('dim_customer') }} as customers
inner join tutorial_customer as source
    on customers.customer_key =
        {{ personal_data_key('source.customer_ssn', 'customer.ssn', 'ssn') }}
" --limit 10
```

You should see the same protected identity and business attributes as Layer2. Layer3 changes the
analytical shape of the project, not the Personal Data state of this customer.

## What you have observed

The readable record exists in the raw boundary and the separately governed map. Protected
relations carry only stable keys for identifying attributes. Controlled case views can resolve a
narrow approved set of fields, but only for `case_users` and `privacy_admins`.

Next, [trace an invalid invoice into quarantine](trace-an-invoice-into-quarantine.md).

Read [Versioned, domain-separated keys](../explanation/versioned-domain-separated-keys.md) for the
reason behind the key design, or consult the
[`priva_map` model reference](../reference/priva-map.md) for exact columns.
