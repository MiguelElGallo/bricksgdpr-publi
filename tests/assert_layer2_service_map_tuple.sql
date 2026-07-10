{{ config(tags=['layer2_services', 'personal_data_control']) }}

select
    services.customer_key,
    services.service_key,
    services.service_version_key,
    services.installation_address_key
from {{ ref('int_customer_services_resolved') }} as services
left anti join {{ ref('fa_pd_service_address') }} as mapped
    on services.customer_key = mapped.customer_key
    and services.service_key = mapped.service_key
    and services.service_version_key = mapped.service_version_key
    and services.installation_address_key = mapped.installation_address_key
