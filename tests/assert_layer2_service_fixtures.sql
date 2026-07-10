{{ config(tags=['layer2_services', 'control_fixture', 'deletion_control']) }}

with fixture_metrics as (
    select
        (
            select count(*) from {{ ref('quarantine_customer_services') }}
            where service_id = 'SVC-0098-A' and quarantine_reason = 'CUSTOMER_NOT_FOUND'
        ) as late_count,
        (
            select count(*) from {{ ref('quarantine_customer_services') }}
            where service_id = 'SVC-0013-B' and quarantine_reason = 'INVALID_VALIDITY_FLAG'
        ) as invalid_flag_count,
        (
            select count(*) from {{ ref('quarantine_customer_services') }}
            where service_id = 'SVC-0014-A' and quarantine_reason = 'INVALID_VALIDITY_PERIOD'
        ) as invalid_period_count,
        (
            select count(*) from {{ ref('quarantine_customer_services') }}
            where service_id = 'SVC-0099-A'
        ) + (
            select count(*)
            from {{ ref('int_customer_services_resolved') }}
            where service_key = {{ personal_data_key("'SVC-0099-A'", 'service.id') }}
        ) as deleted_output_count
)

select *
from fixture_metrics
where
    late_count != 1
    or invalid_flag_count != 1
    or invalid_period_count != 1
    or deleted_output_count != 0
