{{ config(tags=['layer3_dimensions']) }}

with current_customers as (
    select
        customer_key,
        customer_pk_key,
        customer_id_key,
        first_name_key,
        last_name_key,
        full_name_key,
        email_key,
        phone_key,
        birth_date_key,
        address_key,
        customer_segment,
        is_active,
        source_updated_at
    from {{ ref('int_customer_protected') }}
),

erased_subject_member as (
    select
        {{ erased_member_key() }} as customer_key,
        {{ erased_member_key() }} as customer_pk_key,
        {{ erased_member_key() }} as customer_id_key,
        {{ erased_member_key() }} as first_name_key,
        {{ erased_member_key() }} as last_name_key,
        {{ erased_member_key() }} as full_name_key,
        {{ erased_member_key() }} as email_key,
        {{ erased_member_key() }} as phone_key,
        {{ erased_member_key() }} as birth_date_key,
        {{ erased_member_key() }} as address_key,
        'ERASED_SUBJECT' as customer_segment,
        false as is_active,
        cast('1900-01-01 00:00:00' as timestamp) as source_updated_at
)

select * from current_customers
union all
select * from erased_subject_member
