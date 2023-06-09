{% macro fueled_snowflake_get_incremental_sql(strategy, tmp_relation, target_relation, unique_key, upsert_date_key, dest_columns, disable_upsert_lookback) %}
  {% if strategy == 'merge' %}
    {% do return(fueled_utils.fueled_merge(tmp_relation, target_relation, unique_key, upsert_date_key, dest_columns, disable_upsert_lookback)) %}
  {% elif strategy == 'delete+insert' %}
    {% do return(fueled_utils.fueled_delete_insert(tmp_relation, target_relation, unique_key, upsert_date_key, dest_columns, disable_upsert_lookback)) %}
  {% else %}
    {% do exceptions.raise_compiler_error('invalid strategy: ' ~ strategy) %}
  {% endif %}
{% endmacro %}


{% materialization fueled_incremental, adapter='snowflake' -%}

  {% set original_query_tag = set_query_tag() %}

  {%- set full_refresh_mode = (should_full_refresh()) -%}

  {# Required keys. Throws error if not present #}
  {%- set unique_key = config.require('unique_key') -%}
  {%- set upsert_date_key = config.require('upsert_date_key') -%}
  
  {% set disable_upsert_lookback = config.get('disable_upsert_lookback') %}

  {% set target_relation = this %}
  {% set existing_relation = load_relation(this) %}
  {% set tmp_relation = make_temp_relation(this) %}

  {# Validate early so we don't run SQL if the strategy is invalid or missing keys #}
  {% set strategy = fueled_utils.fueled_validate_get_incremental_strategy(config) -%}

  -- setup
  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {% if existing_relation is none %}
    {% set build_sql = create_table_as(False, target_relation, sql) %}
  {% elif existing_relation.is_view %}
    {#-- Can't overwrite a view with a table - we must drop --#}
    {{ log("Dropping relation " ~ target_relation ~ " because it is a view and this model is a table.") }}
    {% do adapter.drop_relation(existing_relation) %}
    {% set build_sql = create_table_as(False, target_relation, sql) %}
  {% elif full_refresh_mode %}
    {% set build_sql = create_table_as(False, target_relation, sql) %}
  {% else %}
    {% do run_query(create_table_as(True, tmp_relation, sql)) %}
    {% do adapter.expand_target_column_types(
           from_relation=tmp_relation,
           to_relation=target_relation) %}
    
    {%- set dest_columns = adapter.get_columns_in_relation(target_relation) -%}

    {% set build_sql = fueled_utils.fueled_snowflake_get_incremental_sql(strategy,
                                                                             tmp_relation,
                                                                             target_relation,
                                                                             unique_key,
                                                                             upsert_date_key,
                                                                             dest_columns,
                                                                             disable_upsert_lookback)%}
  {% endif %}

  {%- call statement('main') -%}
    {{ build_sql }}
  {%- endcall -%}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {{ adapter.commit() }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {% set target_relation = target_relation.incorporate(type='table') %}
  {% do persist_docs(target_relation, model) %}

  {% do unset_query_tag(original_query_tag) %}

  {{ return({'relations': [target_relation]}) }}

{%- endmaterialization %}
