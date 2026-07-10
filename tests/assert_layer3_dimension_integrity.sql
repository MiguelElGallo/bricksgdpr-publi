{{ config(tags=['layer3_dimensions', 'personal_data_control']) }}

with customer_differences as (
    (
        select * from {{ ref('dim_customer') }}
        except
        select * from {{ ref('int_customer_protected') }}
    )
    union all
    (
        select * from {{ ref('int_customer_protected') }}
        except
        select * from {{ ref('dim_customer') }}
    )
),

service_differences as (
    (
        select * from {{ ref('dim_service') }}
        except
        select * from {{ ref('int_customer_services_resolved') }}
    )
    union all
    (
        select * from {{ ref('int_customer_services_resolved') }}
        except
        select * from {{ ref('dim_service') }}
    )
)

select 'customer' as dimension_name, customer_key as record_key
from customer_differences
union all
select 'service', service_version_key
from service_differences
