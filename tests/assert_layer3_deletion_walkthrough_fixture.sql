{{ config(tags=['layer3', 'deletion_control', 'control_fixture']) }}

with subject_keys as (
    select distinct
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0099'
),

expected_layer3_targets as (
    select target_layer, target_relation, target_kind
    from ({{ customer_deletion_target_relations() }})
    where target_layer = 'layer3'
),

source_candidates as (
    select
        (
            select count(*)
            from {{ ref('stg_customer') }}
            where customer_id = 'CUST-0099' and source_operation = 'UPSERT' and is_active
        ) as customer_rows,
        (
            select count(*)
            from {{ ref('stg_customer_services') }}
            where
                service_id = 'SVC-0099-A'
                and customer_ssn = '900-00-0199'
                and is_valid
                and valid_to >= valid_from
        ) as service_rows,
        (
            select count(*)
            from {{ ref('stg_customer_events') }}
            where event_id = 'EVT-0099' and customer_ssn = '900-00-0199'
        ) as event_rows,
        (
            select count(*)
            from {{ ref('stg_invoices') }}
            where
                invoice_id = 'INV-0099'
                and customer_ssn = '900-00-0199'
                and service_id = 'SVC-0099-A'
                and due_date >= issued_date
        ) as invoice_rows
),

plan_metrics as (
    select
        count(*) as plan_rows,
        count(distinct plan.customer_key) as historical_keys,
        count(distinct plan.target_relation) as target_relations,
        count_if(targets.target_relation is null) as unexpected_targets
    from {{ ref('int_customer_deletion_plan') }} as plan
    left join expected_layer3_targets as targets
        on plan.target_layer = targets.target_layer
        and plan.target_relation = targets.target_relation
        and plan.target_kind = targets.target_kind
    where plan.deletion_request_id = 'CCHG-0099-D' and plan.target_layer = 'layer3'
),

layer3_metrics as (
    select
        (select count(*) from {{ ref('dim_customer') }}) as dim_customer_rows,
        (select count(*) from {{ ref('dim_service') }}) as dim_service_rows,
        (select count(*) from {{ ref('dim_date') }}) as dim_date_rows,
        (select count(*) from {{ ref('fct_customer_event') }}) as event_rows,
        (select count(*) from {{ ref('fct_invoice') }}) as invoice_rows,
        (
            select count(*) from {{ ref('dim_customer') }}
            where customer_key in (select customer_key from subject_keys)
        ) as subject_customer_rows,
        (
            select count(*) from {{ ref('dim_service') }}
            where customer_key in (select customer_key from subject_keys)
        ) as subject_service_rows,
        (
            select count(*) from {{ ref('fct_customer_event') }}
            where
                customer_key in (select customer_key from subject_keys)
                or event_key = 'EVT-0099'
        ) as subject_event_rows,
        (
            select count(*) from {{ ref('fct_invoice') }}
            where
                customer_key in (select customer_key from subject_keys)
                or invoice_key = 'INV-0099'
        ) as subject_invoice_rows
),

control_state as (
    select
        cast('{{ var("deletion_decision_as_of") }}' as timestamp)
            < cast('2026-02-16 08:00:00' as timestamp) as is_before_confirmation
)

select
    source.*,
    plan.*,
    layer3.*,
    state.is_before_confirmation
from source_candidates as source
cross join plan_metrics as plan
cross join layer3_metrics as layer3
cross join control_state as state
where
    source.customer_rows != 1
    or source.service_rows != 1
    or source.event_rows != 1
    or source.invoice_rows != 1
    or plan.unexpected_targets != 0
    or layer3.dim_date_rows != datediff(
        cast('{{ var("date_dimension_end") }}' as date),
        cast('{{ var("date_dimension_start") }}' as date)
    ) + 1
    or (
        state.is_before_confirmation
        and (
            plan.plan_rows != 0
            or plan.historical_keys != 0
            or plan.target_relations != 0
            or layer3.dim_customer_rows != 16
            or layer3.dim_service_rows != 17
            or layer3.event_rows != 29
            or layer3.invoice_rows != 26
            or layer3.subject_customer_rows != 1
            or layer3.subject_service_rows != 1
            or layer3.subject_event_rows != 1
            or layer3.subject_invoice_rows != 1
        )
    )
    or (
        not state.is_before_confirmation
        and (
            plan.plan_rows != 8
            or plan.historical_keys != 2
            or plan.target_relations != 4
            or layer3.dim_customer_rows != 15
            or layer3.dim_service_rows != 16
            or layer3.event_rows != 28
            or layer3.invoice_rows != 25
            or layer3.subject_customer_rows != 0
            or layer3.subject_service_rows != 0
            or layer3.subject_event_rows != 0
            or layer3.subject_invoice_rows != 0
        )
    )
