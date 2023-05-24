{# Returns the sql to calculate the lower/upper limits of the run #}
{% macro get_run_limits(min_last_success, max_last_success, models_matched_from_manifest, has_matched_all_models, start_date) -%}

  {% set start_tstamp = fueled_utils.cast_to_tstamp(start_date) %}
  {% set min_last_success = fueled_utils.cast_to_tstamp(min_last_success) %}
  {% set max_last_success = fueled_utils.cast_to_tstamp(max_last_success) %}

  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% if models_matched_from_manifest == 0 %}
    {# If no fueled models are in the manifest, start from start_tstamp #}
    {% do fueled_utils.log_message("Fueled: No data in manifest. Processing data from start_date") %}

    {% set run_limits_query %}
      select {{start_tstamp}} as lower_limit,
             least({{ fueled_utils.timestamp_add('day', var("fueled__backfill_limit_days", 30), start_tstamp) }},
                   {{ fueled_utils.current_timestamp_in_utc() }}) as upper_limit
    {% endset %}

  {% elif not has_matched_all_models %}
    {# If a new Fueled model is added which isnt already in the manifest, replay all events up to upper_limit #}
    {% do fueled_utils.log_message("Fueled: New Fueled incremental model. Backfilling") %}

    {% set run_limits_query %}
      select {{ start_tstamp }} as lower_limit,
             least({{ max_last_success }},
                   {{ fueled_utils.timestamp_add('day', var("fueled__backfill_limit_days", 30), start_tstamp) }}) as upper_limit
    {% endset %}

  {% elif min_last_success != max_last_success %}
    {# If all models in the run exists in the manifest but are out of sync, replay from the min last success to the max last success #}
    {% do fueled_utils.log_message("Fueled: Fueled incremental models out of sync. Syncing") %}

    {% set run_limits_query %}
      select {{ fueled_utils.timestamp_add('hour', -var("fueled__lookback_window_hours", 6), min_last_success) }} as lower_limit,
             least({{ max_last_success }},
                  {{ fueled_utils.timestamp_add('day', var("fueled__backfill_limit_days", 30), min_last_success) }}) as upper_limit
    {% endset %}

  {% else %}
    {# Else standard run of the model #}
    {% do fueled_utils.log_message("Fueled: Standard incremental run") %}

    {% set run_limits_query %}
      select
        {{ fueled_utils.timestamp_add('hour', -var("fueled__lookback_window_hours", 6), min_last_success) }} as lower_limit,
        least({{ fueled_utils.timestamp_add('day', var("fueled__backfill_limit_days", 30), min_last_success) }},
              {{ fueled_utils.current_timestamp_in_utc() }}) as upper_limit
    {% endset %}

  {% endif %}

  {{ return(run_limits_query) }}

{% endmacro %}
