{{ config(tags=['personal_data_control']) }}
-- Preserve the existing key inputs for valid fixtures; reject ambiguous input before hashing.
select 'ssn_format_equivalence' as failure
where {{ canonicalize_personal_data("'900-00-0001'", 'ssn') }} <> '900000001'
   or {{ canonicalize_personal_data("'900000001'", 'ssn') }} <> '900000001'
union all
select 'international_phone_equivalence'
where {{ canonicalize_personal_data("'+358-555-0101'", 'phone') }} <> '3585550101'
   or {{ canonicalize_personal_data("'+358 (555) 0101'", 'phone') }} <> '3585550101'
union all
select 'null_preservation'
where {{ canonicalize_personal_data('cast(null as string)', 'ssn') }} is not null
   or {{ canonicalize_personal_data('cast(null as string)', 'phone') }} is not null
