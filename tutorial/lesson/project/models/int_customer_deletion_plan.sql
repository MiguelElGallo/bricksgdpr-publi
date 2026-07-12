{{ config(materialized='view') }}

with historical_identifiers as (
    select distinct
        authorizations.deletion_request_id,
        history.customer_ssn,
        authorizations.deletion_mode,
        authorizations.deletion_policy_version,
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
            ('layer1', 'int_current_customers', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('priva_map', 'demo_customer_map', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('layer2', 'int_customer_protected', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            (
                'layer2', 'int_invoices_resolved',
                'DELETE_CURRENT_ROWS', 'REASSIGN_TO_ERASED_MEMBER'
            ),
            ('layer1', 'quarantine_invoices', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS'),
            ('layer3', 'dim_customer', 'DELETE_CURRENT_ROWS', 'DELETE_CURRENT_ROWS')
    ) as target_relations(
        target_layer,
        target_relation,
        full_deletion_action,
        special_deletion_action
    )
)

select
    identifiers.deletion_request_id,
    identifiers.customer_ssn,
    identifiers.deletion_mode,
    identifiers.deletion_policy_version,
    targets.target_layer,
    targets.target_relation,
    case identifiers.deletion_mode
        when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
        when 'SPECIAL_DELETION' then targets.special_deletion_action
    end as planned_action,
    'AUTHORIZED' as plan_status,
    identifiers.authorized_at
from historical_identifiers as identifiers
cross join targets
