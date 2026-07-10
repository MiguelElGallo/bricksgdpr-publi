with source as (
    select * from {{ ref('customer_events') }}
),

typed as (
    select
        trim(event_id) as event_id,
        trim(customer_ssn) as customer_ssn,
        upper(trim(event_type)) as event_type,
        cast(occurred_at as timestamp) as occurred_at,
        cast(measure_value as decimal(18, 2)) as measure_value,
        upper(trim(measure_unit)) as measure_unit,
        cast(source_updated_at as timestamp) as source_updated_at
    from source
)

select * from typed
