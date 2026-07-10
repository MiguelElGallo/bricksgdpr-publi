{{ config(tags=['layer2_customer', 'personal_data_control']) }}

select protected.*
from {{ ref('int_customer_protected') }} as protected
left anti join {{ ref('fa_pd_customer') }} as mapped
    on protected.customer_key = mapped.customer_key
    and protected.customer_pk_key = mapped.customer_pk_key
    and protected.customer_id_key = mapped.customer_id_key
    and protected.first_name_key = mapped.first_name_key
    and protected.last_name_key = mapped.last_name_key
    and protected.full_name_key = mapped.full_name_key
    and protected.email_key = mapped.email_key
    and protected.phone_key = mapped.phone_key
    and protected.birth_date_key = mapped.birth_date_key
    and protected.address_key = mapped.address_key
