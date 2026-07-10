{{ config(tags=['layer3_facts']) }}

select invoice_key, is_paid, paid_date_key
from {{ ref('fct_invoice') }}
where
    (is_paid and paid_date_key is null)
    or (not is_paid and paid_date_key is not null)
