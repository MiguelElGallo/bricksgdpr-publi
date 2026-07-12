{% macro customer_deletion_target_relations() -%}
{{ generate_customer_deletion_target_relations([
    {'target_layer': 'layer1', 'model_name': 'quarantine_customer_events', 'model_type': 'QUARANTINE'},
    {'target_layer': 'layer1', 'model_name': 'quarantine_customer_services', 'model_type': 'QUARANTINE'},
    {'target_layer': 'layer1', 'model_name': 'quarantine_invoices', 'model_type': 'QUARANTINE'},
    {'target_layer': 'priva_map', 'model_name': 'fa_pd_customer', 'model_type': 'MAPPING'},
    {'target_layer': 'priva_map', 'model_name': 'fa_pd_service_address', 'model_type': 'MAPPING'},
    {'target_layer': 'layer2', 'model_name': 'int_customer_protected', 'model_type': 'IDENTITY'},
    {'target_layer': 'layer2', 'model_name': 'int_customer_events_resolved', 'model_type': 'FACT'},
    {'target_layer': 'layer2', 'model_name': 'int_customer_services_resolved', 'model_type': 'SERVICE'},
    {'target_layer': 'layer2', 'model_name': 'int_invoices_resolved', 'model_type': 'FACT'},
    {'target_layer': 'layer3', 'model_name': 'dim_customer', 'model_type': 'DIMENSION'},
    {'target_layer': 'layer3', 'model_name': 'dim_service', 'model_type': 'DIMENSION'},
    {'target_layer': 'layer3', 'model_name': 'fct_customer_event', 'model_type': 'FACT'},
    {'target_layer': 'layer3', 'model_name': 'fct_invoice', 'model_type': 'FACT'},
    {'target_layer': 'layer3_case', 'model_name': 'case_dim_customer', 'model_type': 'CASE_VIEW'},
    {'target_layer': 'layer3_case', 'model_name': 'case_dim_service', 'model_type': 'CASE_VIEW'},
    {'target_layer': 'layer3_case', 'model_name': 'case_fct_customer_event', 'model_type': 'CASE_VIEW'},
    {'target_layer': 'layer3_case', 'model_name': 'case_fct_invoice', 'model_type': 'CASE_VIEW'}
]) }}
{%- endmacro %}

{% macro erased_member_key() -%}
'{{ var("erased_member_key") | replace("'", "''") }}'
{%- endmacro %}
