select assert_true(
    lower(session_user()) = lower({{expected_user}}),
    concat('Unexpected run identity: ', session_user())
);

select assert_true(
    not is_member('admins')
    and not is_account_group_member('privacy_admins')
    and is_account_group_member('restricted_users')
    and not is_account_group_member('case_users'),
    'Unexpected persona group membership vector'
);

select assert_true(
    count(*) > 0
    and count_if(
        customer_pk_value = customer_pk_key
        and customer_id_value = customer_id_key
        and customer_ssn_value = customer_key
        and first_name_value = first_name_key
        and last_name_value = last_name_key
        and full_name_value = full_name_key
        and email_value = email_key
        and phone_value = phone_key
        and birth_date_value = birth_date_key
        and address_value = address_key
    ) = count(*),
    'Restricted user received an unmasked customer value'
)
from bricksgdpr.priva_map.fa_pd_customer;

select assert_true(
    count(*) > 0
    and count_if(
        service_id_value = service_key
        and customer_ssn_value = customer_key
        and installation_address_value = installation_address_key
    ) = count(*),
    'Restricted user received an unmasked service value'
)
from bricksgdpr.priva_map.fa_pd_service_address;

select assert_true(
    (select count(*) from bricksgdpr.layer2.int_customer_protected) > 0
    and (select count(*) from bricksgdpr.layer3.dim_customer) > 0
    and (select count(*) from bricksgdpr.layer3.fct_invoice) > 0,
    'Restricted user cannot read the protected relations'
);
