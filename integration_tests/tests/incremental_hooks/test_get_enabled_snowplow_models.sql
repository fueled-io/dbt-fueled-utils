{# Tests:
   1 - Find all enabled models with the fueled_web_incremental tag
   2 - Find subset of enabled and tagged models using the dbt ls command. Performed via bash script
   3 - Test error message for untagged models. Performed by changing 'tag_var' via bash script. #}

{{ config(tags=["requires_script"]) }}

{% set dummy_graph={
    'nodes':
    {
        'model.fueled_web.enabled_model_w_dependency':
        {
            'config': {'enabled': true},
            'depends_on':{'nodes':['model.fueled_web.fueled_web_base_events_this_run']},
            'resource_type': 'model',
            'tags':[var("tag_var",'fueled_web_incremental')],
            "name": "enabled_model_w_dependency"
        },
        'model.fueled_web.enabled_model_wo_dependency':
        {
            'config': {'enabled': true},
            'depends_on':{'nodes':['model.fueled_web.fueled_web_sessions']},
            'resource_type': 'model',
            'tags':[var("tag_var",'fueled_web_incremental')],
            "name": "enabled_model_wo_dependency"
        },
        'model.fueled_web.disabled_model':
        {
            'config': {'enabled': false},
            'depends_on':{'nodes':['model.fueled_web.fueled_web_base_events_this_run']},
            'resource_type': 'model',
            'tags':[var("tag_var",'fueled_web_incremental')],
            "name": "disabled_model"
        },
        'model.non_fueled_model':
        {
            'config': {'enabled': true},
            'depends_on':{'nodes':['model.dummy']},
            'resource_type': 'model',
            'tags':['dummy'],
            "name": "non_fueled_model"
        },
        'test.non_model':
        {
            'config': {'enabled': true},
            'depends_on':{'nodes':['model.fueled_web.fueled_web_base_events_this_run']},
            'resource_type': 'test',
            "name": "non_model"
        }  
    }
} %}

{% set actual_enabled_models = fueled_utils.get_enabled_fueled_models('fueled_web', graph_object=dummy_graph) %}

{% if var("models_to_run","")|length %}
    {# Test 2 #}
    {% set expected_enabled_models = ['enabled_model_w_dependency'] %}
{% else %}
    {# Test 1 #}
    {% set expected_enabled_models = ['enabled_model_w_dependency', 'enabled_model_wo_dependency'] %}
{% endif %}


{% if actual_enabled_models == expected_enabled_models %}
    select 1 as result limit 0 {# returns no rows therefore test passes #}
{% else %}
    select 1 as result {# returns rows therefore test fails #}
{% endif %}
