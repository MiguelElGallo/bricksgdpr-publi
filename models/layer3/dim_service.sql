{{ config(tags=['layer3_dimensions']) }}

with current_services as (
    select
        customer_key,
        service_key,
        service_version_key,
        installation_address_key,
        service_type,
        is_valid,
        valid_from,
        valid_to,
        source_updated_at
    from {{ ref('int_customer_services_resolved') }}
),

erased_subject_member as (
    select
        {{ erased_member_key() }} as customer_key,
        {{ erased_member_key() }} as service_key,
        {{ erased_member_key() }} as service_version_key,
        {{ erased_member_key() }} as installation_address_key,
        'ERASED_SUBJECT' as service_type,
        false as is_valid,
        cast('1900-01-01' as date) as valid_from,
        cast('1900-01-01' as date) as valid_to,
        cast('1900-01-01 00:00:00' as timestamp) as source_updated_at
)

select * from current_services
union all
select * from erased_subject_member
