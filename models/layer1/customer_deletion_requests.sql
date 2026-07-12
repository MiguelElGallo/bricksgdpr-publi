{{ config(
    materialized='incremental',
    unique_key='deletion_request_id',
    incremental_strategy='merge',
    on_schema_change='fail',
    tags=['deletion_control', 'personal_data_control'],
    databricks_tags={
        'contains_personal_data': 'true',
        'personal_data_area': 'deletion_control'
    }
) }}

select
    customer_change_id as deletion_request_id,
    customer_id,
    customer_ssn,
    source_updated_at as source_deleted_at,
    current_timestamp() as detected_at,
    'DETECTED' as detection_status
from {{ ref('stg_customer') }}
where source_operation = 'DELETE'

{% if is_incremental() %}
    and customer_change_id not in (
        select deletion_request_id from {{ this }}
    )
{% endif %}
