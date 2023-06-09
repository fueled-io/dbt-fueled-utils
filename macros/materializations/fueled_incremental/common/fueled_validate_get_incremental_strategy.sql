{% macro fueled_validate_get_incremental_strategy(config) -%}
  {{ adapter.dispatch('fueled_validate_get_incremental_strategy', 'fueled_utils')(config) }}
{%- endmacro %}


{% macro default__fueled_validate_get_incremental_strategy(config) %}

  {% if execute %}
    {%- set error_message = "Warning: the `fueled_incremental` materialization is deprecated and should be replaced with dbt's `incremental` materialization, setting `fueled_optimize=true` in your model config, and setting the appropriate dispatch search order in your project. See https://docs.fueled.io//docs/modeling-your-data/modeling-your-data-with-dbt/dbt-advanced-usage/dbt-incremental-logic-pre-release for more details. The `fueled_incremental` materialization will be removed completely in a future version of the package." -%}
    {%- do exceptions.warn(error_message) -%}
  {% endif %}

  {# Find and validate the incremental strategy #}
  {%- set strategy = config.get("incremental_strategy", default="merge") -%}

  {# This shouldn't be required but due to some issue with dbt 1.3 this should resolve the default value not getting assigned #}
  {% if strategy is none %}
    {%- set strategy = 'merge' -%}
  {% endif %}

  {% set invalid_strategy_msg -%}
    Invalid incremental strategy provided: {{ strategy }}
    Expected 'merge'
  {%- endset %}
  {% if strategy not in ['merge'] %}
    {% do exceptions.raise_compiler_error(invalid_strategy_msg) %}
  {% endif %}

  {% do return(strategy) %}

{% endmacro %}


{% macro snowflake__fueled_validate_get_incremental_strategy(config) %}

  {% if execute %}
    {%- set error_message = "Warning: the `fueled_incremental` materialization is deprecated and should be replaced with dbt's `incremental` materialization, setting `fueled_optimize=true` in your model config, and setting the appropriate dispatch search order in your project. See https://docs.fueled.io//docs/modeling-your-data/modeling-your-data-with-dbt/dbt-advanced-usage/dbt-incremental-logic-pre-release for more details. The `fueled_incremental` materialization will be removed completely in a future version of the package." -%}
    {%- do exceptions.warn(error_message) -%}
  {% endif %}

  {# Find and validate the incremental strategy #}
  {%- set strategy = config.get("incremental_strategy", default="merge") -%}

  {# This shouldn't be required but due to some issue with dbt 1.3 this should resolve the default value not getting assigned #}
  {% if strategy is none %}
    {%- set strategy = 'merge' -%}
  {% endif %}

  {% set invalid_strategy_msg -%}
    Invalid incremental strategy provided: {{ strategy }}
    Expected one of: 'merge', 'delete+insert'
  {%- endset %}
  {% if strategy not in ['merge', 'delete+insert'] %}
    {% do exceptions.raise_compiler_error(invalid_strategy_msg) %}
  {% endif %}

  {% do return(strategy) %}

{% endmacro %}
