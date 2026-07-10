{{ config(tags=['layer2', 'deletion_control']) }}

with durable_matches as (
    select 'customer' as relation_name, customer_key
    from {{ ref('int_customer_protected') }}
    where customer_key in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})

    union all

    select 'events', customer_key
    from {{ ref('int_customer_events_resolved') }}
    where customer_key in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})

    union all

    select 'services', customer_key
    from {{ ref('int_customer_services_resolved') }}
    where customer_key in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})

    union all

    select 'invoices', customer_key
    from {{ ref('int_invoices_resolved') }}
    where customer_key in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})
),

quarantine_matches as (
    select 'quarantine_events' as relation_name, event_id as record_id
    from {{ ref('quarantine_customer_events') }}
    where
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }}
        in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})

    union all

    select 'quarantine_services', service_id
    from {{ ref('quarantine_customer_services') }}
    where
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }}
        in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})

    union all

    select 'quarantine_invoices', invoice_id
    from {{ ref('quarantine_invoices') }}
    where
        {{ personal_data_key('customer_ssn', 'customer.ssn', 'ssn') }}
        in (select customer_key from {{ ref('int_terminal_deleted_customer_keys') }})
)

select relation_name, customer_key as record_identifier
from durable_matches
union all
select relation_name, record_id
from quarantine_matches
