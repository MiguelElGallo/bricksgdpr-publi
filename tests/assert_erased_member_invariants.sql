{{ config(tags=['deletion_control', 'layer3']) }}

with violations as (
    select 'dim_customer_special_member' as invariant
    where (
        select count(*)
        from {{ ref('dim_customer') }}
        where
            customer_key = {{ erased_member_key() }}
            and customer_pk_key = {{ erased_member_key() }}
            and customer_id_key = {{ erased_member_key() }}
            and first_name_key = {{ erased_member_key() }}
            and last_name_key = {{ erased_member_key() }}
            and full_name_key = {{ erased_member_key() }}
            and email_key = {{ erased_member_key() }}
            and phone_key = {{ erased_member_key() }}
            and birth_date_key = {{ erased_member_key() }}
            and address_key = {{ erased_member_key() }}
            and customer_segment = 'ERASED_SUBJECT'
            and not is_active
    ) != 1

    union all

    select 'dim_service_special_member'
    where (
        select count(*)
        from {{ ref('dim_service') }}
        where
            customer_key = {{ erased_member_key() }}
            and service_key = {{ erased_member_key() }}
            and service_version_key = {{ erased_member_key() }}
            and installation_address_key = {{ erased_member_key() }}
            and service_type = 'ERASED_SUBJECT'
            and not is_valid
    ) != 1

    union all

    select 'event_flag_key_equivalence'
    where exists (
        select 1
        from {{ ref('fct_customer_event') }}
        where
            (is_erased_customer and customer_key != {{ erased_member_key() }})
            or (not is_erased_customer and customer_key = {{ erased_member_key() }})
    )

    union all

    select 'invoice_flag_key_equivalence'
    where exists (
        select 1
        from {{ ref('fct_invoice') }}
        where
            (
                is_erased_customer
                and (
                    customer_key != {{ erased_member_key() }}
                    or service_key != {{ erased_member_key() }}
                    or service_version_key != {{ erased_member_key() }}
                )
            )
            or (
                not is_erased_customer
                and (
                    customer_key = {{ erased_member_key() }}
                    or service_key = {{ erased_member_key() }}
                    or service_version_key = {{ erased_member_key() }}
                )
            )
    )
)

select * from violations
