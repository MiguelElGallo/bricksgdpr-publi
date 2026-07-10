{{ config(tags=['case_views', 'personal_data_control']) }}

with view_counts as (
    select
        (select count(*) from {{ ref('case_dim_customer') }}) as case_customer_count,
        (select count(*) from {{ ref('case_dim_service') }}) as case_service_count,
        (select count(*) from {{ ref('case_fct_customer_event') }}) as case_event_count,
        (select count(*) from {{ ref('case_fct_invoice') }}) as case_invoice_count,
        (select count(*) from {{ ref('dim_customer') }}) as protected_customer_count,
        (select count(*) from {{ ref('dim_service') }}) as protected_service_count,
        (select count(*) from {{ ref('fct_customer_event') }}) as protected_event_count,
        (select count(*) from {{ ref('fct_invoice') }}) as protected_invoice_count
)

select *
from view_counts
where
    {{ case_access_predicate() }}
    and (
        case_customer_count != protected_customer_count
        or case_service_count != protected_service_count
        or case_event_count != protected_event_count
        or case_invoice_count != protected_invoice_count
    )
