select assert_true(
    lower(session_user()) = lower({{expected_user}}),
    concat('Unexpected run identity: ', session_user())
);

select assert_true(
    not is_member('admins')
    and not is_account_group_member('privacy_admins')
    and not is_account_group_member('restricted_users')
    and is_account_group_member('case_users'),
    'Unexpected persona group membership vector'
);

select assert_true(
    (select count(*) from bricksgdpr.layer3_case.case_dim_customer) > 0
    and (select count(*) from bricksgdpr.layer3_case.case_dim_service) > 0
    and (select count(*) from bricksgdpr.layer3_case.case_fct_customer_event) > 0
    and (select count(*) from bricksgdpr.layer3_case.case_fct_invoice) > 0,
    'Case user cannot read the approved case views'
);

select assert_true(
    count(*) > 0
    and count_if(
        customer_id <> customer_id_key
        and full_name <> full_name_key
        and email <> email_key
        and customer_address <> address_key
    ) = count(*)
    and count(distinct customer_id) = count(*)
    and count(distinct full_name) = count(*)
    and count(distinct email) = count(*)
    and count(distinct customer_address) = count(*),
    'Case customer view did not resolve every approved readable value'
)
from bricksgdpr.layer3_case.case_dim_customer;

select assert_true(
    count(*) > 0
    and count_if(
        service_id <> service_key
        and installation_address <> installation_address_key
    ) = count(*)
    and count(
        distinct concat_ws('|', service_id, cast(valid_from as string))
    ) = count(*),
    'Case service view did not resolve every approved readable value'
)
from bricksgdpr.layer3_case.case_dim_service;

select assert_true(
    count(*) = (select count(*) from bricksgdpr.layer3_case.case_fct_customer_event)
    and count_if(
        facts.full_name = customers.full_name
        and facts.email = customers.email
    ) = count(*),
    'Case event values do not match the authorized customer dimension'
)
from bricksgdpr.layer3_case.case_fct_customer_event as facts
inner join bricksgdpr.layer3_case.case_dim_customer as customers
    on facts.customer_key = customers.customer_key;

select assert_true(
    count(*) = (select count(*) from bricksgdpr.layer3_case.case_fct_invoice)
    and count_if(
        facts.full_name = customers.full_name
        and facts.email = customers.email
        and facts.service_id = services.service_id
        and facts.installation_address = services.installation_address
    ) = count(*),
    'Case invoice values do not match the authorized dimensions'
)
from bricksgdpr.layer3_case.case_fct_invoice as facts
inner join bricksgdpr.layer3_case.case_dim_customer as customers
    on facts.customer_key = customers.customer_key
inner join bricksgdpr.layer3_case.case_dim_service as services
    on facts.customer_key = services.customer_key
    and facts.service_key = services.service_key
    and facts.service_version_key = services.service_version_key;
