{{ config(tags=['case_views']) }}

select
    events.event_key,
    events.customer_key,
    customers.full_name_key,
    customers.email_key,
    events.event_date_key,
    events.occurred_at,
    events.event_type,
    events.measure_value,
    events.measure_unit,
    mapped.full_name_value as full_name,
    mapped.email_value as email
from {{ ref('fct_customer_event') }} as events
inner join {{ ref('dim_customer') }} as customers
    on events.customer_key = customers.customer_key
inner join {{ ref('fa_pd_customer') }} as mapped
    on customers.customer_key = mapped.customer_key
    and customers.full_name_key = mapped.full_name_key
    and customers.email_key = mapped.email_key
where {{ case_access_predicate() }} and not events.is_erased_customer
