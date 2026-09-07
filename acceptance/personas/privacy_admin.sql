select assert_true(
    lower(session_user()) = lower({{expected_user}}),
    concat('Unexpected run identity: ', session_user())
);

select assert_true(
    not is_member('admins')
    and is_account_group_member('privacy_admins')
    and not is_account_group_member('restricted_users')
    and not is_account_group_member('case_users'),
    'Unexpected persona group membership vector'
);

select assert_true(
    (select count(*) from bricksgdpr.layer1.stg_customer) > 0
    and (select count(*) from bricksgdpr.layer1.quarantine_customer_services) > 0,
    'Layer1 or quarantine is not readable'
);

select assert_true(
    count(*) > 0
    and count_if(
        customer_pk_value <> customer_pk_key
        and customer_id_value <> customer_id_key
        and customer_ssn_value <> customer_key
        and first_name_value <> first_name_key
        and last_name_value <> last_name_key
        and full_name_value <> full_name_key
        and email_value <> email_key
        and phone_value <> phone_key
        and birth_date_value <> birth_date_key
        and address_value <> address_key
    ) = count(*),
    'Privacy administrator did not receive every readable customer value'
)
from bricksgdpr.priva_map.fa_pd_customer;

select assert_true(
    count(*) > 0
    and count_if(
        service_id_value <> service_key
        and customer_ssn_value <> customer_key
        and installation_address_value <> installation_address_key
    ) = count(*),
    'Privacy administrator did not receive every readable service value'
)
from bricksgdpr.priva_map.fa_pd_service_address;

-- Admission comes from the durable terminal ledger, not a raw DELETE event.
-- Resolve historical SSNs through trusted Layer1 evidence without invoking the denied UDF.
with admitted_requests as (
    select deletion_request_id
    from bricksgdpr.layer2.int_terminal_deleted_customer_keys
    union
    select initial_deletion_request_id
    from bricksgdpr.layer2.int_terminal_deleted_customer_keys
),

suppressed_ssns as (
    select distinct regexp_replace(trim(history.customer_ssn), '-', '') as normalized_ssn
    from admitted_requests as admitted
    inner join bricksgdpr.layer1.customer_deletion_requests as requests
        on admitted.deletion_request_id = requests.deletion_request_id
    inner join bricksgdpr.layer1.stg_customer as history
        on requests.customer_id = history.customer_id
    where history.customer_ssn is not null
),

ranked_upserts as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by source_updated_at desc, customer_change_id desc
        ) as change_rank
    from bricksgdpr.layer1.stg_customer
    where source_operation = 'UPSERT'
),

current_source as (
    select *
    from ranked_upserts as upserts
    left anti join suppressed_ssns as deletions
        on regexp_replace(trim(upserts.customer_ssn), '-', '') = deletions.normalized_ssn
    where upserts.change_rank = 1 and upserts.is_active
)

select assert_true(
    count(*) = (select count(*) from bricksgdpr.priva_map.fa_pd_customer)
    and count(*) = (select count(*) from current_source)
    and count_if(
        mapped.customer_pk_value = cast(source.customer_pk as string)
        and mapped.customer_id_value = source.customer_id
        and mapped.customer_ssn_value = source.customer_ssn
        and mapped.first_name_value = source.first_name
        and mapped.last_name_value = source.last_name
        and mapped.full_name_value = nullif(
            concat_ws(' ', source.first_name, source.last_name),
            ''
        )
        and mapped.email_value = source.email
        and mapped.phone_value = source.phone
        and mapped.birth_date_value = date_format(source.birth_date, 'yyyy-MM-dd')
        and mapped.address_value = nullif(
            concat_ws(
                ', ',
                source.address_line1,
                source.address_line2,
                concat_ws(' ', source.postal_code, source.city),
                source.country_code
            ),
            ''
        )
    ) = count(*),
    'Readable customer mapping does not match the trusted Layer1 current source'
)
from bricksgdpr.priva_map.fa_pd_customer as mapped
inner join current_source as source
    on mapped.customer_id_value = source.customer_id
    and mapped.customer_ssn_value = source.customer_ssn;

-- Admission comes from the durable terminal ledger, not a raw DELETE event.
-- Resolve historical SSNs through trusted Layer1 evidence without invoking the denied UDF.
with admitted_requests as (
    select deletion_request_id
    from bricksgdpr.layer2.int_terminal_deleted_customer_keys
    union
    select initial_deletion_request_id
    from bricksgdpr.layer2.int_terminal_deleted_customer_keys
),

suppressed_ssns as (
    select distinct regexp_replace(trim(history.customer_ssn), '-', '') as normalized_ssn
    from admitted_requests as admitted
    inner join bricksgdpr.layer1.customer_deletion_requests as requests
        on admitted.deletion_request_id = requests.deletion_request_id
    inner join bricksgdpr.layer1.stg_customer as history
        on requests.customer_id = history.customer_id
    where history.customer_ssn is not null
),

ranked_upserts as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by source_updated_at desc, customer_change_id desc
        ) as change_rank
    from bricksgdpr.layer1.stg_customer
    where source_operation = 'UPSERT'
),

current_customers as (
    select upserts.customer_ssn
    from ranked_upserts as upserts
    left anti join suppressed_ssns as deletions
        on regexp_replace(trim(upserts.customer_ssn), '-', '') = deletions.normalized_ssn
    where upserts.change_rank = 1 and upserts.is_active
),

eligible_services as (
    select services.*
    from bricksgdpr.layer1.stg_customer_services as services
    inner join current_customers as customers
        on regexp_replace(trim(services.customer_ssn), '-', '')
            = regexp_replace(trim(customers.customer_ssn), '-', '')
    where services.is_valid and services.valid_to >= services.valid_from
)

select assert_true(
    count(*) = (select count(*) from bricksgdpr.priva_map.fa_pd_service_address)
    and count(*) = (select count(*) from eligible_services)
    and count_if(
        mapped.service_id_value = source.service_id
        and mapped.customer_ssn_value = source.customer_ssn
        and mapped.installation_address_value = nullif(
            concat_ws(
                ', ',
                source.installation_address_line1,
                source.installation_address_line2,
                concat_ws(
                    ' ',
                    source.installation_postal_code,
                    source.installation_city
                ),
                source.installation_country_code
            ),
            ''
        )
    ) = count(*),
    'Readable service mapping does not match the trusted Layer1 source'
)
from bricksgdpr.priva_map.fa_pd_service_address as mapped
inner join eligible_services as source
    on mapped.service_id_value = source.service_id
    and mapped.customer_ssn_value = source.customer_ssn
    and mapped.valid_from = source.valid_from;

select assert_true(
    (select count(*) from bricksgdpr.layer2.int_customer_protected) > 0
    and (select count(*) from bricksgdpr.layer3.dim_customer) > 0
    and (select count(*) from bricksgdpr.layer3.fct_customer_event) > 0,
    'Protected relations are not readable'
);

select assert_true(
    (select count(*) from bricksgdpr.layer3_case.case_dim_customer)
        = (select count(*) from bricksgdpr.layer3.dim_customer where customer_key <> '-99999')
    and (select count(*) from bricksgdpr.layer3_case.case_dim_service)
        = (select count(*) from bricksgdpr.layer3.dim_service where customer_key <> '-99999')
    and (select count(*) from bricksgdpr.layer3_case.case_fct_customer_event)
        = (select count(*) from bricksgdpr.layer3.fct_customer_event where customer_key <> '-99999')
    and (select count(*) from bricksgdpr.layer3_case.case_fct_invoice)
        = (select count(*) from bricksgdpr.layer3.fct_invoice where customer_key <> '-99999'),
    'Privacy administrator case-view grains do not match protected parents'
);
