-- depends_on: {{ ref('demo_customer_map') }}
-- Accepted formatting variants must produce identical keys; null values stay null.
-- Rejected inputs are exercised by test:dbt because they must raise rather than return rows.
with checks as (
    select
        {{ demo_personal_data_key("'900-00-0001'", 'customer.ssn', 'ssn') }}
            = {{ demo_personal_data_key("'900000001'", 'customer.ssn', 'ssn') }} as ssn_stable,
        {{ demo_personal_data_key("'+358 (555) 0101'", 'customer.phone', 'phone') }}
            = {{ demo_personal_data_key("'+3585550101'", 'customer.phone', 'phone') }} as phone_stable,
        {{ demo_personal_data_key("'  CUSTOMER01@EXAMPLE.INVALID  '", 'customer.email') }}
            = {{ demo_personal_data_key("'customer01@example.invalid'", 'customer.email') }} as text_stable,
        {{ demo_personal_data_key('null', 'customer.ssn', 'ssn') }} is null as null_preserved,
        {{ demo_personal_data_key("'same-value'", 'customer.email') }}
            != {{ demo_personal_data_key("'same-value'", 'customer.name') }} as domain_separated
)
select * from checks
-- SQL comparisons can be NULL; a missing result must fail the contract too.
where (ssn_stable and phone_stable and text_stable and null_preserved and domain_separated)
    is distinct from true
