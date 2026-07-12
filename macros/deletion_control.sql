{% macro customer_deletion_target_relations() -%}
select *
from values
    ('layer1', 'quarantine_customer_events', 'TABLE'),
    ('layer1', 'quarantine_customer_services', 'TABLE'),
    ('layer1', 'quarantine_invoices', 'TABLE'),
    ('priva_map', 'fa_pd_customer', 'TABLE'),
    ('priva_map', 'fa_pd_service_address', 'TABLE'),
    ('layer2', 'int_customer_protected', 'TABLE'),
    ('layer2', 'int_customer_events_resolved', 'TABLE'),
    ('layer2', 'int_customer_services_resolved', 'TABLE'),
    ('layer2', 'int_invoices_resolved', 'TABLE'),
    ('layer3', 'dim_customer', 'TABLE'),
    ('layer3', 'dim_service', 'TABLE'),
    ('layer3', 'fct_customer_event', 'TABLE'),
    ('layer3', 'fct_invoice', 'TABLE'),
    ('layer3_case', 'case_dim_customer', 'VIEW'),
    ('layer3_case', 'case_dim_service', 'VIEW'),
    ('layer3_case', 'case_fct_customer_event', 'VIEW'),
    ('layer3_case', 'case_fct_invoice', 'VIEW')
    as targets(target_layer, target_relation, target_kind)
{%- endmacro %}
