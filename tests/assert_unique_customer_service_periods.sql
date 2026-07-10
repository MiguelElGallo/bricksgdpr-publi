{{ config(tags=['layer1', 'layer2_services']) }}

select service_id, valid_from, count(*) as row_count
from {{ ref('stg_customer_services') }}
group by service_id, valid_from
having count(*) > 1
