{% macro customer_deletion_target_relations() -%}
select *
from values
    ('layer1', 'quarantine_customer_events', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer1', 'quarantine_customer_services', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer1', 'quarantine_invoices', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('priva_map', 'fa_pd_customer', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('priva_map', 'fa_pd_service_address', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer2', 'int_customer_protected', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer2', 'int_customer_events_resolved', 'TABLE', 'REASSIGN_TO_ERASED_MEMBER'),
    ('layer2', 'int_customer_services_resolved', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer2', 'int_invoices_resolved', 'TABLE', 'REASSIGN_TO_ERASED_MEMBER'),
    ('layer3', 'dim_customer', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer3', 'dim_service', 'TABLE', 'DELETE_CURRENT_ROWS'),
    ('layer3', 'fct_customer_event', 'TABLE', 'REASSIGN_TO_ERASED_MEMBER'),
    ('layer3', 'fct_invoice', 'TABLE', 'REASSIGN_TO_ERASED_MEMBER'),
    ('layer3_case', 'case_dim_customer', 'VIEW', 'EXCLUDE_ERASED_ROWS'),
    ('layer3_case', 'case_dim_service', 'VIEW', 'EXCLUDE_ERASED_ROWS'),
    ('layer3_case', 'case_fct_customer_event', 'VIEW', 'EXCLUDE_ERASED_ROWS'),
    ('layer3_case', 'case_fct_invoice', 'VIEW', 'EXCLUDE_ERASED_ROWS')
    as targets(target_layer, target_relation, target_kind, planned_action)
{%- endmacro %}

{% macro erased_member_key() -%}
'{{ var("erased_member_key") | replace("'", "''") }}'
{%- endmacro %}
