{{ config(tags=['layer1', 'control_fixture']) }}

with seed_counts as (
    select 'customer' as seed_name, count(*) as row_count from {{ ref('customer') }}
    union all
    select 'customer_events', count(*) from {{ ref('customer_events') }}
    union all
    select 'customer_services', count(*) from {{ ref('customer_services') }}
    union all
    select 'invoices', count(*) from {{ ref('invoices') }}
)

select *
from seed_counts
where row_count not between 10 and 100
