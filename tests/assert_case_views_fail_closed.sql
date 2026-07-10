{{ config(tags=['case_views', 'personal_data_control']) }}

{% do ref('case_dim_customer') %}
{% do ref('case_dim_service') %}
{% do ref('case_fct_customer_event') %}
{% do ref('case_fct_invoice') %}

with case_counts as (
    select
        (select count(*) from {{ ref('case_dim_customer') }}) as customer_count,
        (select count(*) from {{ ref('case_dim_service') }}) as service_count,
        (select count(*) from {{ ref('case_fct_customer_event') }}) as event_count,
        (select count(*) from {{ ref('case_fct_invoice') }}) as invoice_count
)

select *
from case_counts
where
    not {{ case_access_predicate() }}
    and (customer_count != 0 or service_count != 0 or event_count != 0 or invoice_count != 0)
