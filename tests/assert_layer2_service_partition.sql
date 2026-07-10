{{ config(tags=['layer2_services', 'deletion_control']) }}

with expected_services as (
    select services.service_version_key
    from {{ ref('int_customer_services_keyed') }} as services
    left anti join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on services.customer_key = deletions.customer_key
),

actual_service_counts as (
    select service_version_key, count(*) as occurrence_count
    from (
        select service_version_key from {{ ref('int_customer_services_resolved') }}
        union all
        select
            {{ personal_data_key(
                "concat_ws('|', service_id, date_format(valid_from, 'yyyy-MM-dd'))",
                'service.version'
            ) }} as service_version_key
        from {{ ref('quarantine_customer_services') }}
    ) as outputs
    group by service_version_key
),

partition_differences as (
    select
        coalesce(expected.service_version_key, actual.service_version_key) as service_version_key,
        expected.service_version_key is not null as expected_to_exist,
        coalesce(actual.occurrence_count, 0) as occurrence_count
    from expected_services as expected
    full outer join actual_service_counts as actual
        on expected.service_version_key = actual.service_version_key
    where expected.service_version_key is null or coalesce(actual.occurrence_count, 0) != 1
)

select *
from partition_differences
