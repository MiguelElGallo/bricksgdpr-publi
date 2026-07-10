{{ config(tags=['priva_map', 'personal_data_control']) }}

with udf_checks as (
    select
        {{ function('pseudonymize_personal_data_v1') }}(
            'customer01@example.invalid', 'customer.email'
        ) = {{ function('pseudonymize_personal_data_v1') }}(
            'customer01@example.invalid', 'customer.email'
        ) as deterministic,
        {{ function('pseudonymize_personal_data_v1') }}(
            'same-value', 'customer.email'
        ) <> {{ function('pseudonymize_personal_data_v1') }}(
            'same-value', 'customer.full_name'
        ) as domain_separated,
        {{ function('pseudonymize_personal_data_v1') }}(
            cast(null as string), 'customer.email'
        ) is null as null_preserved,
        {{ function('pseudonymize_personal_data_v1') }}(
            'customer01@example.invalid', 'customer.email'
        ) like 'v1:%' as version_prefixed,
        {{ personal_data_key("' Customer01@Example.Invalid '", 'customer.email') }}
            = {{ personal_data_key("'customer01@example.invalid'", 'customer.email') }}
            as canonical_equivalence,
        {{ function('hash_personal_data') }}(
            'customer01@example.invalid',
            'customer.email',
            'v1',
            secret('bricksgdpr', 'pepper_v1')
        ) = {{ function('pseudonymize_personal_data_v1') }}(
            'customer01@example.invalid', 'customer.email'
        ) as core_matches_wrapper
)

select *
from udf_checks
where
    deterministic is not true
    or domain_separated is not true
    or null_preserved is not true
    or version_prefixed is not true
    or canonical_equivalence is not true
    or core_matches_wrapper is not true
