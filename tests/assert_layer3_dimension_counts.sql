{{ config(tags=['layer3_dimensions', 'control_fixture']) }}

with dimension_counts as (
    select
        (select count(*) from {{ ref('dim_customer') }}) as customer_count,
        (select count(*) from {{ ref('dim_service') }}) as service_count,
        (select count(*) from {{ ref('dim_date') }}) as date_count,
        (select count(*) from {{ ref('int_customer_protected') }}) as expected_customer_count,
        (
            select count(*) from {{ ref('int_customer_services_resolved') }}
        ) as expected_service_count,
        datediff(
            cast('{{ var("date_dimension_end") }}' as date),
            cast('{{ var("date_dimension_start") }}' as date)
        ) + 1 as expected_date_count
)

select *
from dimension_counts
where
    customer_count != expected_customer_count
    or service_count != expected_service_count
    or date_count != expected_date_count
