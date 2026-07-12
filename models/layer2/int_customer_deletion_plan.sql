{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=[
        'decision_revision_id',
        'customer_key',
        'target_layer',
        'target_relation',
        'deletion_mode',
        'deletion_policy_version'
    ],
    on_schema_change='fail',
    tags=['deletion_control', 'personal_data_control']
) }}

with authorized_revisions as (
    select
        decision_revision_id,
        deletion_request_id,
        customer_id,
        deletion_mode,
        deletion_policy_version,
        recorded_at,
        decided_at
    from {{ ref('customer_deletion_authorization_history') }}
    where authorization_status = 'AUTHORIZED'
),

historical_customer_keys as (
    select distinct
        authorizations.decision_revision_id,
        authorizations.deletion_request_id,
        {{ personal_data_key('history.customer_ssn', 'customer.ssn', 'ssn') }} as customer_key,
        authorizations.deletion_mode,
        authorizations.deletion_policy_version,
        authorizations.recorded_at as authorization_recorded_at,
        authorizations.decided_at as authorized_at
    from authorized_revisions as authorizations
    inner join {{ ref('stg_customer') }} as history
        on authorizations.customer_id = history.customer_id
    where history.customer_ssn is not null
),

target_relations as (
    {{ customer_deletion_target_relations() }}
)

select
    keys.decision_revision_id,
    keys.deletion_request_id,
    keys.customer_key,
    keys.deletion_mode,
    keys.deletion_policy_version,
    keys.authorization_recorded_at,
    targets.target_layer,
    targets.target_relation,
    targets.target_kind,
    case keys.deletion_mode
        when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
        when 'SPECIAL_DELETION' then targets.special_deletion_action
    end as planned_action,
    'AUTHORIZED' as plan_status,
    keys.authorized_at
from historical_customer_keys as keys
cross join target_relations as targets
