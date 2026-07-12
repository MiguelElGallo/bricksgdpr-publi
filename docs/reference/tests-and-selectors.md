---
title: Tests and selectors
icon: lucide/test-tube-2
---

# Tests and selectors

The project contains 335 data tests and 7 unit tests.

## Test counts

| Test class | Count | Definition location |
| --- | ---: | --- |
| `not_null` generic data tests | 224 | Model YAML files |
| `unique` generic data tests | 28 | Model YAML files |
| `relationships` generic data tests | 14 | Model YAML files |
| `accepted_values` generic data tests | 22 | Model YAML files |
| Generated deletion-contract data tests | 5 | Model YAML files and generator macro |
| Singular data tests | 42 | `tests/*.sql` |
| Unit tests | 7 | Deletion-control, erased-fact, invoice-quality, and service-resolution model YAML files |
| **Total data tests** | **335** | Generic plus singular |
| **Total including unit tests** | **342** | Data tests plus unit tests |

The count does not include positive/negative persona SQL tasks under `acceptance/personas/`; those
are external acceptance checks, not dbt test nodes.

## Singular data tests

### Source and fixture controls

| Test | Contract |
| --- | --- |
| `assert_seed_row_bounds` | Each of the four source-extract seeds contains 10 through 100 rows |
| `assert_customer_deletion_fixture` | Delete, post-delete upsert, historical SSN, and inactive controls have exact shapes |
| `assert_customer_deletion_control` | Three requests, four authorized revisions, exact mode actions, 102 plan rows, escalation, and same-mode evidence are exact |
| `assert_layer3_deletion_walkthrough_fixture` | Before, SPECIAL-only, and final mixed-mode states have exact Layer3 totals and plan coverage |
| `assert_erased_member_invariants` | Special members and every fact flag/key tuple remain globally consistent |
| `assert_customer_deletion_generators` | Generated FACT, policy-applied FACT, delete-style, CASE_VIEW, and all target-type actions match the canonical matrix |
| `assert_unconfirmed_deletion_not_authorized` | Pending deletion is detected but has no plan and remains in mapping, Layer2, and Layer3 |
| `assert_layer1_control_fixtures` | Late, invalid, inconsistent-payment, and deleted-dependent source controls exist exactly once |
| `assert_unique_customer_service_periods` | `service_id + valid_from` is unique in staged services |

### Mapping and function controls

| Test | Contract |
| --- | --- |
| `assert_priva_map_contract` | Default 15/17 counts, v1 prefixes, domain separation, and fixture exclusions |
| `assert_priva_map_masks_attached` | Exact 13 raw-column masks and `USING COLUMNS` mappings |
| `assert_priva_map_tags_attached` | Exact map table tags and Personal Data column category/state tags |
| `assert_personal_data_udfs` | Determinism, domain separation, null behavior, prefix, canonical equivalence, and core/wrapper equivalence |

### Layer2 controls

| Test | Contract |
| --- | --- |
| `assert_layer2_customer_map_tuple` | Every protected customer key tuple exists in the customer map |
| `assert_layer2_event_fixtures` | Late event quarantines, SPECIAL retains under `-99999`, and FULL removes its event |
| `assert_layer2_event_partition` | Every ordinary/SPECIAL event appears once; every FULL event appears zero times |
| `assert_layer2_service_fixtures` | Late/invalid service reasons and deletion exclusion match fixtures |
| `assert_layer2_service_partition` | Every nondeleted service period appears once across accepted/quarantine |
| `assert_layer2_service_map_tuple` | Every accepted service has a complete matching map tuple |
| `assert_layer2_invoice_due_logic` | `is_due` matches the configured inclusive as-of expression |
| `assert_layer2_invoice_fixtures` | Exact 27/11 counts, SPECIAL/FULL outcomes, and control reasons |
| `assert_layer2_invoice_partition` | Every invoice has one accepted, quarantine, or authorized-suppression outcome |
| `assert_layer2_invoice_service_tuple` | Every accepted invoice has one effective accepted service tuple |
| `assert_layer2_no_raw_columns` | No finite forbidden raw name or disallowed `_value` suffix exists in Layer2 |
| `assert_layer2_terminal_deletion` | Original deleted keys are absent from accepted and quarantine Layer2 outputs |

### Layer3 controls

| Test | Contract |
| --- | --- |
| `assert_layer3_dimension_counts` | Customer/service counts equal Layer2 plus one erased member; date count matches range |
| `assert_layer3_dimension_integrity` | Non-special dimension rows exactly equal their Layer2 inputs |
| `assert_layer3_fact_counts` | Fact counts match accepted Layer2 inputs |
| `assert_layer3_fact_integrity` | Fact rows exactly match their expected Layer2 projection |
| `assert_layer3_invoice_dimension_tuple` | Every invoice fact matches a complete service-dimension tuple |
| `assert_layer3_invoice_payment_invariants` | Paid invoices have paid date; unpaid invoices do not |
| `assert_layer3_no_raw_columns` | No finite forbidden raw name or disallowed `_value` suffix exists in Layer3 |
| `assert_protected_no_readable_tags` | Protected schemas have no `RAW` or `CONTROLLED_READABLE` column tag |
| `assert_layer3_terminal_deletion` | Original deleted keys are absent from dimensions and facts; SPECIAL uses only the sentinel |

### Case controls

| Test | Contract |
| --- | --- |
| `assert_case_view_grains` | Authorized case-view counts equal protected parents excluding special/erased rows |
| `assert_case_views_are_standard_views` | All four case relations are views whose stored SQL contains the required erased-row filter |
| `assert_case_views_fail_closed` | Under an unaffiliated session, all four case views return zero rows |
| `assert_case_views_terminal_deletion` | Deleted keys are absent from all case views |

### Access controls

| Test | Contract |
| --- | --- |
| `assert_access_relation_grants` | Direct relation privileges in the selected canonical or prefixed schemas equal the exact persona `SELECT` allowlist and contain no other privilege type |
| `assert_access_parent_privileges` | Direct catalog/schema privileges equal the `USE_CATALOG`/`USE_SCHEMA` allowlist |
| `assert_access_no_consumer_function_privileges` | Persona groups have no routine privilege in the project catalog |
| `assert_access_no_ambient_grants` | No unexpected direct grantee appears in catalog, schema, relation, or routine metadata |

**Source:** `tests/`.

## Unit tests

| Unit test | Model | Expected row |
| --- | --- | --- |
| `invalid_confirmations_fail_closed` | `customer_deletion_authorization_history` | Missing/unsupported evidence is `INVALID` |
| `service_arriving_before_customer_is_quarantined` | `int_customer_service_resolution` | `SVC-LATE-A`, `CUSTOMER_NOT_FOUND` |
| `quarantined_service_recovers_when_customer_arrives` | `int_customer_service_resolution` | `SVC-LATE-A`, `ACCEPTED` |
| `erased_event_uses_special_customer_member` | `int_customer_event_resolution` | Ordinary false, SPECIAL `-99999`, FULL absent |
| `erased_invoice_uses_special_customer_and_service_members` | `int_invoice_resolution` | Ordinary retained, SPECIAL tuple `-99999`, FULL absent |
| `erased_invoice_still_checks_quality_rules` | `int_invoice_resolution` | SPECIAL does not promote invalid invoices |
| `latest_same_mode_policy_revision_wins` | `int_terminal_deleted_customer_keys` | Latest effective revision plus preserved initial evidence |

Seed-specific singular tests additionally prove suppression detection and end-to-end reassignment.

**Source:** `models/layer1/_deletion_control.yml`, `models/layer2/_layer2_*.yml`.

## Test limitations

| Area | Limit |
| --- | --- |
| Fixture counts and IDs | Valid only for the checked-in generated seeds |
| No-raw tests | Inspect column names and selected tags, not arbitrary data payloads |
| Map tag/mask tests | Exact for the two current mapping tables; new mapping relations require allowlist updates |
| Access metadata | Measures direct grants visible to the executing caller, not every transitive/effective entitlement |
| Case grain/deletion tests | Result depends on executing session; the deletion test expands an owner-level plan/UDF dependency |
| Persona uniqueness assertions | Synthetic case SQL assumes readable names, emails, and addresses are unique |

For the role of executable metadata checks, see
[Executable security controls](../explanation/executable-security-controls.md).

## Tags

| Tag | Selects |
| --- | --- |
| `layer1` | Seeds, staging, quarantine, and related tests |
| `priva_map` | Mapping models and map controls |
| `layer2` | Protected Layer2 models and shared Layer2 controls |
| `layer2_customer` | Customer-projection resources |
| `layer2_events` | Event boundary, resolution, accepted/quarantine resources |
| `layer2_services` | Service boundary, resolution, accepted/quarantine resources |
| `layer2_invoices` | Invoice boundary, resolution, accepted/quarantine resources |
| `quarantine` | Three quarantine tables |
| `layer3` | Protected dimensions/facts and shared controls |
| `layer3_dimensions` | Dimension resources and controls |
| `layer3_facts` | Fact resources and controls |
| `case_views` | Four case views and case controls |
| `access_control` | Four live access metadata tests |
| `deletion_control` | Detection ledger, confirmation gate, authorized plan, execution gate, and tests |
| `personal_data_control` | Key, tag, mask, schema, and access invariants |
| `control_fixture` | Exact synthetic fixture assertions |

Other classification tags include `gdpr`, `personal_data`, `non_personal_data`, and
`source_simulator`.

## Selector forms

| Form | Meaning |
| --- | --- |
| `tag:<tag>` | Every enabled node carrying the tag |
| `+tag:<tag>` | Tagged nodes plus all upstream ancestors |
| `<node_name>` | Exact node-name selection |
| `<selection_a> <selection_b>` | Union of two dbt selections when passed as one quoted argument |
| `--exclude tag:access_control` | Removes live access tests from the selected graph |

No `selectors.yml` file or named selector is defined.
