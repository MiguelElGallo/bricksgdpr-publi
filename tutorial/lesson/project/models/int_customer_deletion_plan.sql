{{ config(materialized='view') }}

with historical_identifiers as (
    select distinct
        authorizations.deletion_request_id,
        history.customer_ssn,
        authorizations.decided_at as authorized_at
    from {{ ref('int_customer_deletion_authorizations') }} as authorizations
    inner join {{ ref('stg_customer') }} as history
        on authorizations.customer_id = history.customer_id
    where
        authorizations.authorization_status = 'AUTHORIZED'
        and history.customer_ssn is not null
),

targets as (
    select *
    from (
        values
            ('layer1', 'int_current_customers'),
            ('priva_map', 'demo_customer_map'),
            ('layer2', 'int_customer_protected'),
            ('layer2', 'int_invoices_resolved'),
            ('layer1', 'quarantine_invoices'),
            ('layer3', 'dim_customer')
    ) as target_relations(target_layer, target_relation)
)

select
    identifiers.deletion_request_id,
    identifiers.customer_ssn,
    targets.target_layer,
    targets.target_relation,
    'DELETE_CURRENT_ROWS' as planned_action,
    'AUTHORIZED' as plan_status,
    identifiers.authorized_at
from historical_identifiers as identifiers
cross join targets
