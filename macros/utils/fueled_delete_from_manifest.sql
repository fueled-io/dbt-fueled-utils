{# Deletes specified models from the incremental_manifest table #}
{% macro fueled_delete_from_manifest(models, incremental_manifest_table) %}

  {# Ensure models is a list #}
  {%- if models is string -%}
    {%- set models = [models] -%}
  {%- endif -%}

  {# No models to delete or not in execute mode #}
  {% if not models|length or not execute %}
    {{ return('') }}
  {% endif %}

  {# Get the manifest table to ensure it exits #}
  {%- set incremental_manifest_table_exists = adapter.get_relation(incremental_manifest_table.database,
                                                                  incremental_manifest_table.schema,
                                                                  incremental_manifest_table.name) -%}

  {%- if not incremental_manifest_table_exists -%}
    {{return(dbt_utils.log_info("Fueled: "+incremental_manifest_table|string+" does not exist"))}}
  {%- endif -%}

  {# Get all models in the manifest and compare to list of models to delete #}
  {%- set models_in_manifest = dbt_utils.get_column_values(table=incremental_manifest_table, column='model') -%}
  {%- set unmatched_models, matched_models = [], [] -%}

  {%- for model in models -%}

    {%- if model in models_in_manifest -%}
      {%- do matched_models.append(model) -%}
    {%- else -%}
      {%- do unmatched_models.append(model) -%}
    {%- endif -%}

  {%- endfor -%}

  {%- if not matched_models|length -%}
    {{return(dbt_utils.log_info("Fueled: None of the supplied models exist in the manifest"))}}
  {%- endif -%}

  {% set delete_statement %}
    {%- if target.type in ['databricks', 'spark'] -%}
      delete from {{ incremental_manifest_table }} where model in ({{ fueled_utils.print_list(matched_models) }});
    {%- else -%}
      -- We don't need transaction but Redshift needs commit statement while BQ does not. By using transaction we cover both.
      begin;
      delete from {{ incremental_manifest_table }} where model in ({{ fueled_utils.print_list(matched_models) }});
      commit;
    {%- endif -%}
  {% endset %}

  {%- do run_query(delete_statement) -%}

  {%- if matched_models|length -%}
    {% do fueled_utils.log_message("Fueled: Deleted models "+fueled_utils.print_list(matched_models)+" from the manifest") %}
  {%- endif -%}

  {%- if unmatched_models|length -%}
    {% do fueled_utils.log_message("Fueled: Models "+fueled_utils.print_list(unmatched_models)+" do not exist in the manifest") %}
  {%- endif -%}

{% endmacro %}

{# Package specific macro. Makes the API less cumbersome for the user #}
{% macro fueled_web_delete_from_manifest(models) %}

  {{ fueled_utils.fueled_delete_from_manifest(models, ref('fueled_web_incremental_manifest')) }}

{% endmacro %}

{% macro fueled_mobile_delete_from_manifest(models) %}

  {{ fueled_utils.fueled_delete_from_manifest(models, ref('fueled_mobile_incremental_manifest')) }}

{% endmacro %}
