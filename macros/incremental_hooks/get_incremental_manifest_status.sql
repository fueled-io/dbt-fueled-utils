{% macro get_incremental_manifest_status(incremental_manifest_table, models_in_run) -%}

  {# In case of not execute just return empty strings to avoid hitting database #}
  {% if not execute %}
    {{ return(['', '', '', '']) }}
  {% endif %}

  {% set target_relation = adapter.get_relation(
        database=incremental_manifest_table.database,
        schema=incremental_manifest_table.schema,
        identifier=incremental_manifest_table.name) %}

  {% if target_relation is not none %}

    {% set last_success_query %}
      select min(last_success) as min_last_success,
            max(last_success) as max_last_success,
            coalesce(count(*), 0) as models
      from {{ incremental_manifest_table }}
      where model in ({{ fueled_utils.print_list(models_in_run) }})
    {% endset %}

    {% set results = run_query(last_success_query) %}

    {% if execute %}

      {% set min_last_success = results.columns[0].values()[0] %}
      {% set max_last_success = results.columns[1].values()[0] %}
      {% set models_matched_from_manifest = results.columns[2].values()[0] %}
      {% set has_matched_all_models = true if models_matched_from_manifest == models_in_run|length else false %}

      {{ return([min_last_success, max_last_success, models_matched_from_manifest, has_matched_all_models]) }}

    {% endif %}


  {% else %}

    {% do exceptions.warn("Fueled Warning: " ~ incremental_manifest_table ~ " does not exist. This is expected if you are compiling a fresh installation of the dbt-fueled-* packages.") %}

    {{ return(['9999-01-01 00:00:00', '9999-01-01 00:00:00', 0, false]) }}

  {% endif %}


{%- endmacro %}

{# Prints the run limits for the run to the console #}
{% macro print_run_limits(run_limits_relation) -%}

  {% set run_limits_query %}
    select lower_limit, upper_limit from {{ run_limits_relation }}
  {% endset %}

  {# Derive limits from manifest instead of selecting from limits table since run_query executes during 2nd parse the limits table is yet to be updated. #}
  {% set results = run_query(run_limits_query) %}

  {% if execute %}

    {% set lower_limit = fueled_utils.tstamp_to_str(results.columns[0].values()[0]) %}
    {% set upper_limit = fueled_utils.tstamp_to_str(results.columns[1].values()[0]) %}
    {% set run_limits_message = "Fueled: Processing data between " + lower_limit + " and " + upper_limit %}

    {% do fueled_utils.log_message(run_limits_message) %}

  {% endif %}

{%- endmacro %}
