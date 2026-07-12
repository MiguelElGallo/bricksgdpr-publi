{{ config(tags=['layer3', 'deletion_control', 'control_fixture']) }}

with subject_keys as (
    select distinct
        customer_id,
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }} as customer_key
    from {{ ref('stg_customer') }}
    where customer_id in ('CUST-0097', 'CUST-0099') and customer_ssn is not null
),

expected_layer3_targets as (
    select *
    from ({{ customer_deletion_target_relations() }})
    where target_layer = 'layer3'
),

source_candidates as (
    select
        (
            select count(*) from {{ ref('stg_customer') }}
            where customer_id in ('CUST-0097', 'CUST-0099')
                and source_operation = 'UPSERT' and is_active
        ) as customer_rows,
        (
            select count(*) from {{ ref('stg_customer_services') }}
            where service_id in ('SVC-0097-A', 'SVC-0099-A')
                and is_valid and valid_to >= valid_from
        ) as service_rows,
        (
            select count(*) from {{ ref('stg_customer_events') }}
            where event_id in ('EVT-0097', 'EVT-0099')
        ) as event_rows,
        (
            select count(*) from {{ ref('stg_invoices') }}
            where invoice_id in ('INV-0097', 'INV-0099') and due_date >= issued_date
        ) as invoice_rows
),

plan_metrics as (
    select
        count(*) as plan_rows,
        count(distinct concat(plan.decision_revision_id, '|', plan.customer_key))
            as key_revision_rows,
        count(distinct plan.target_relation) as target_relations,
        count_if(plan.planned_action = 'REASSIGN_TO_ERASED_MEMBER') as reassignment_plan_rows,
        count_if(targets.target_relation is null) as unexpected_targets
    from {{ ref('int_customer_deletion_plan') }} as plan
    left join expected_layer3_targets as targets
        on plan.target_layer = targets.target_layer
        and plan.target_relation = targets.target_relation
        and plan.target_kind = targets.target_kind
        and plan.planned_action = case plan.deletion_mode
            when 'FULL_GOVERNED_OUTPUT_DELETION' then targets.full_deletion_action
            when 'SPECIAL_DELETION' then targets.special_deletion_action
        end
    where plan.target_layer = 'layer3'
),

ledger_state as (
    select
        count_if(keys.customer_id = 'CUST-0097' and ledger.deletion_mode = 'SPECIAL_DELETION')
            as special_0097_keys,
        count_if(keys.customer_id = 'CUST-0099' and ledger.deletion_mode = 'SPECIAL_DELETION')
            as special_0099_keys,
        count_if(
            keys.customer_id = 'CUST-0099'
            and ledger.deletion_mode = 'FULL_GOVERNED_OUTPUT_DELETION'
        ) as full_0099_keys
    from subject_keys as keys
    inner join {{ ref('int_terminal_deleted_customer_keys') }} as ledger
        on keys.customer_key = ledger.customer_key
),

control_state as (
    select
        case
            when special_0097_keys = 0 and special_0099_keys = 0 and full_0099_keys = 0
                then 'BEFORE_CONFIRMATION'
            when special_0097_keys = 0 and special_0099_keys = 2 and full_0099_keys = 0
                then 'SPECIAL_0099'
            when special_0097_keys = 1 and special_0099_keys = 0 and full_0099_keys = 2
                then 'FINAL_MIXED_MODES'
            else 'UNEXPECTED'
        end as state_name
    from ledger_state
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
        ) as original_customer_rows,
        (
            select count(*) from {{ ref('dim_service') }}
            where customer_key in (select customer_key from subject_keys)
        ) as original_service_rows,
        (
            select count(*) from {{ ref('fct_customer_event') }}
            where customer_key in (select customer_key from subject_keys)
        ) as original_event_rows,
        (
            select count(*) from {{ ref('fct_invoice') }}
            where customer_key in (select customer_key from subject_keys)
        ) as original_invoice_rows,
        (
            select count(*) from {{ ref('fct_customer_event') }}
            where event_key = 'EVT-0097' and customer_key = {{ erased_member_key() }}
                and is_erased_customer
        ) as special_event_rows,
        (
            select count(*) from {{ ref('fct_invoice') }}
            where invoice_key = 'INV-0097' and customer_key = {{ erased_member_key() }}
                and service_key = {{ erased_member_key() }}
                and service_version_key = {{ erased_member_key() }}
                and is_erased_customer
        ) as special_invoice_rows,
        (
            select count(*) from {{ ref('fct_customer_event') }} where event_key = 'EVT-0099'
        ) as full_event_rows,
        (
            select count(*) from {{ ref('fct_invoice') }} where invoice_key = 'INV-0099'
        ) as full_invoice_rows
),

expected_state as (
    select * from values
        ('BEFORE_CONFIRMATION', 0, 0, 0, 18, 20, 31, 28, 2, 2, 2, 2, 0, 0, 1, 1),
        ('SPECIAL_0099', 8, 2, 4, 17, 19, 31, 28, 1, 1, 1, 1, 0, 0, 1, 1),
        ('FINAL_MIXED_MODES', 24, 6, 8, 16, 18, 30, 27, 0, 0, 0, 0, 1, 1, 0, 0)
        as expected(
            state_name, plan_rows, key_revision_rows, reassignment_plan_rows,
            dim_customer_rows, dim_service_rows, event_rows, invoice_rows,
            original_customer_rows, original_service_rows, original_event_rows,
            original_invoice_rows, special_event_rows, special_invoice_rows,
            full_event_rows, full_invoice_rows
        )
)

select source.*, plan.*, layer3.*, state.state_name
from source_candidates as source
cross join plan_metrics as plan
cross join layer3_metrics as layer3
cross join control_state as state
left join expected_state as expected on state.state_name = expected.state_name
where
    source.customer_rows != 2
    or source.service_rows != 2
    or source.event_rows != 2
    or source.invoice_rows != 2
    or expected.state_name is null
    or plan.unexpected_targets != 0
    or plan.target_relations != case when state.state_name = 'BEFORE_CONFIRMATION' then 0 else 4 end
    or layer3.dim_date_rows != datediff(
        cast('{{ var("date_dimension_end") }}' as date),
        cast('{{ var("date_dimension_start") }}' as date)
    ) + 1
    or plan.plan_rows != expected.plan_rows
    or plan.key_revision_rows != expected.key_revision_rows
    or plan.reassignment_plan_rows != expected.reassignment_plan_rows
    or layer3.dim_customer_rows != expected.dim_customer_rows
    or layer3.dim_service_rows != expected.dim_service_rows
    or layer3.event_rows != expected.event_rows
    or layer3.invoice_rows != expected.invoice_rows
    or layer3.original_customer_rows != expected.original_customer_rows
    or layer3.original_service_rows != expected.original_service_rows
    or layer3.original_event_rows != expected.original_event_rows
    or layer3.original_invoice_rows != expected.original_invoice_rows
    or layer3.special_event_rows != expected.special_event_rows
    or layer3.special_invoice_rows != expected.special_invoice_rows
    or layer3.full_event_rows != expected.full_event_rows
    or layer3.full_invoice_rows != expected.full_invoice_rows
