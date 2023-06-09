{# Tests both RS/PG (delete/insert) and BQ/Snowflake/Databricks (merge)
incremental materialization with lookback disabled.
   upsert_date_key: RS/PG/Databricks only. Key used to limit the table scan
   partition_by: BQ only. Key used to limit table scan #}

{{
  config(
    materialized='incremental',
    unique_key='id',
    upsert_date_key='start_tstamp',
    disable_upsert_lookback=true,
    partition_by = fueled_utils.get_value_by_target_type(bigquery_val={
      "field": "start_tstamp",
      "data_type": "timestamp"
    }),
    tags=["requires_script"],
    fueled_optimize=true
  )
}}

with data as (
  select * from {{ ref('data_incremental') }}
  {% if target.type == 'snowflake' %}
    -- data set intentionally contains dupes.
    -- Snowflake merge will error if dupes occur. Removing for test
    where not (run = 1 and id = 2 and start_tstamp = '2021-03-03 00:00:00')
  {% endif %}
)

{% if is_incremental() %}

  select
    id,
    start_tstamp

  from data
  where run = 2

{% else %}

  select
    id,
    start_tstamp

  from data
  where run = 1

{% endif %}
