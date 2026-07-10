{{ config(tags=['case_views']) }}

select
    services.customer_key,
    services.service_key,
    services.service_version_key,
    services.installation_address_key,
    services.service_type,
    services.is_valid,
    services.valid_from,
    services.valid_to,
    mapped.service_id_value as service_id,
    mapped.installation_address_value as installation_address
from {{ ref('dim_service') }} as services
inner join {{ ref('fa_pd_service_address') }} as mapped
    on services.customer_key = mapped.customer_key
    and services.service_key = mapped.service_key
    and services.service_version_key = mapped.service_version_key
    and services.installation_address_key = mapped.installation_address_key
where {{ case_access_predicate() }}
