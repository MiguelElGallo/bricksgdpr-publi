{{ config(materialized='ephemeral', tags=['layer2_services']) }}

with nondeleted_services as (
    select services.*
    from {{ ref('int_customer_services_keyed') }} as services
    left anti join {{ ref('int_terminal_deleted_customer_keys') }} as deletions
        on services.customer_key = deletions.customer_key
)

select
    services.*,
    case
        when customers.customer_key is null then 'CUSTOMER_NOT_FOUND'
        when not services.is_valid then 'INVALID_VALIDITY_FLAG'
        when services.valid_to < services.valid_from then 'INVALID_VALIDITY_PERIOD'
        when mapped_services.service_version_key is null then 'PRIVA_MAP_ENTRY_NOT_FOUND'
        else 'ACCEPTED'
    end as resolution_status
from nondeleted_services as services
left join {{ ref('fa_pd_customer') }} as customers
    on services.customer_key = customers.customer_key
left join {{ ref('fa_pd_service_address') }} as mapped_services
    on services.service_version_key = mapped_services.service_version_key
    and services.customer_key = mapped_services.customer_key
    and services.service_key = mapped_services.service_key
    and services.installation_address_key = mapped_services.installation_address_key
