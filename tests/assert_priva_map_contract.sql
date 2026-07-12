{{ config(tags=['priva_map', 'personal_data_control']) }}

with customer_metrics as (
    select
        count(*) as row_count,
        count_if(not customer_key like 'v1:%') as invalid_version_count,
        count_if(
            customer_key = customer_id_key
            or customer_key = email_key
            or customer_id_key = email_key
        ) as domain_collision_count
    from {{ ref('fa_pd_customer') }}
),

service_metrics as (
    select
        count(*) as row_count,
        count_if(not service_version_key like 'v1:%') as invalid_version_count
    from {{ ref('fa_pd_service_address') }}
),

forbidden_customer_keys as (
    select distinct
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
    from {{ ref('stg_customer') }}
    where customer_id in ('CUST-0015', 'CUST-0099')
),

forbidden_service_version_keys as (
    select
        {{ personal_data_key(
            "concat_ws('|', service_id, date_format(valid_from, 'yyyy-MM-dd'))",
            'service.version'
        ) }} as service_version_key
    from {{ ref('stg_customer_services') }}
    where service_id in ('SVC-0014-A', 'SVC-0098-A', 'SVC-0099-A')
),

exclusion_metrics as (
    select
        (
            select count(*)
            from {{ ref('fa_pd_customer') }} as mapped
            inner join forbidden_customer_keys as forbidden
                on mapped.customer_key = forbidden.customer_key
        ) as forbidden_customer_count,
        (
            select count(*)
            from {{ ref('fa_pd_service_address') }} as mapped
            inner join forbidden_service_version_keys as forbidden
                on mapped.service_version_key = forbidden.service_version_key
        ) as forbidden_service_count
)

select
    customer_metrics.row_count as customer_row_count,
    service_metrics.row_count as service_row_count,
    customer_metrics.invalid_version_count as customer_invalid_versions,
    service_metrics.invalid_version_count as service_invalid_versions,
    customer_metrics.domain_collision_count,
    exclusion_metrics.forbidden_customer_count,
    exclusion_metrics.forbidden_service_count
from customer_metrics
cross join service_metrics
cross join exclusion_metrics
where
    customer_metrics.row_count != 15
    or service_metrics.row_count != 17
    or customer_metrics.invalid_version_count != 0
    or service_metrics.invalid_version_count != 0
    or customer_metrics.domain_collision_count != 0
    or exclusion_metrics.forbidden_customer_count != 0
    or exclusion_metrics.forbidden_service_count != 0
