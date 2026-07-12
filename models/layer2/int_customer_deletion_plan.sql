{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['deletion_request_id', 'customer_key', 'target_layer', 'target_relation'],
    on_schema_change='fail',
    tags=['deletion_control', 'personal_data_control']
) }}

with authorized_requests as (
    select
        deletion_request_id,
        customer_id,
        decided_at
    from {{ ref('customer_deletion_authorizations') }}
    where authorization_status = 'AUTHORIZED'
),

historical_customer_keys as (
    select distinct
        authorizations.deletion_request_id,
        {{ personal_data_key('history.customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
        authorizations.decided_at as authorized_at
    from authorized_requests as authorizations
    inner join {{ ref('stg_customer') }} as history
        on authorizations.customer_id = history.customer_id
    where history.customer_ssn is not null
),

target_relations as (
    {{ customer_deletion_target_relations() }}
)

select
    keys.deletion_request_id,
    keys.customer_key,
    targets.target_layer,
    targets.target_relation,
    targets.target_kind,
    'DELETE_CURRENT_ROWS' as planned_action,
    'AUTHORIZED' as plan_status,
    keys.authorized_at
from historical_customer_keys as keys
cross join target_relations as targets
