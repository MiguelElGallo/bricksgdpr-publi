{{ config(tags=['deletion_control', 'control_fixture']) }}

with pending_key as (
    select {{ personal_data_key("'900-00-0097'", 'customer.ssn', 'ssn') }} as customer_key
),

metrics as (
    select
        (
            select count(*) from {{ ref('customer_deletion_requests') }}
            where deletion_request_id = 'CCHG-0097-D'
        ) as detected_count,
        (
            select count(*) from {{ ref('int_customer_deletion_plan') }}
            where deletion_request_id = 'CCHG-0097-D'
        ) as plan_count,
        (
            select count(*) from {{ ref('fa_pd_customer') }}
            where customer_key in (select customer_key from pending_key)
        ) as map_count,
        (
            select count(*) from {{ ref('int_customer_protected') }}
            where customer_key in (select customer_key from pending_key)
        ) as layer2_count,
        (
            select count(*) from {{ ref('dim_customer') }}
            where customer_key in (select customer_key from pending_key)
        ) as layer3_count
)

select *
from metrics
where
    detected_count != 1
    or plan_count != 0
    or map_count != 1
    or layer2_count != 1
    or layer3_count != 1
