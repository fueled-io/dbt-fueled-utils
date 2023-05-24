{# post-hook for incremental runs #}
{% macro fueled_incremental_post_hook(package_name) %}
  
  {% set enabled_fueled_models = fueled_utils.get_enabled_fueled_models(package_name) -%}

  {% set successful_fueled_models = fueled_utils.get_successful_models(models=enabled_fueled_models) -%}

  {% set incremental_manifest_table = fueled_utils.get_incremental_manifest_table_relation(package_name) -%}

  {% set base_events_this_run_table = ref(package_name~'_base_events_this_run') -%}
        
  {{ fueled_utils.update_incremental_manifest_table(incremental_manifest_table, base_events_this_run_table, successful_fueled_models) }}                  

{% endmacro %}
