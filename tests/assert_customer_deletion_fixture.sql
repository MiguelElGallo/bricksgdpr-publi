{{ config(tags=['layer1', 'control_fixture']) }}

with latest_deletion_subject as (
    select
        count_if(source_operation = 'UPSERT') as upsert_count,
        count_if(source_operation = 'DELETE') as delete_count,
        max_by(source_operation, source_updated_at) as latest_operation,
        count(distinct customer_ssn) as historical_ssn_count
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0099'
),

pending_deletion_subject as (
    select
        count_if(source_operation = 'UPSERT') as upsert_count,
        count_if(source_operation = 'DELETE') as delete_count,
        max_by(source_operation, source_updated_at) as latest_operation
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0097'
),

inactive_subject as (
    select
        count(*) as row_count,
        count_if(source_operation = 'UPSERT' and not is_active) as inactive_upsert_count
    from {{ ref('stg_customer') }}
    where customer_id = 'CUST-0015'
)

select
    latest_deletion_subject.*,
    pending_deletion_subject.upsert_count as pending_upsert_count,
    pending_deletion_subject.delete_count as pending_delete_count,
    pending_deletion_subject.latest_operation as pending_latest_operation,
    inactive_subject.row_count as inactive_row_count,
    inactive_subject.inactive_upsert_count
from latest_deletion_subject
cross join pending_deletion_subject
cross join inactive_subject
where
    latest_deletion_subject.upsert_count != 1
    or latest_deletion_subject.delete_count != 1
    or latest_deletion_subject.latest_operation != 'DELETE'
    or latest_deletion_subject.historical_ssn_count != 2
    or pending_deletion_subject.upsert_count != 1
    or pending_deletion_subject.delete_count != 1
    or pending_deletion_subject.latest_operation != 'UPSERT'
    or inactive_subject.row_count != 1
    or inactive_subject.inactive_upsert_count != 1
