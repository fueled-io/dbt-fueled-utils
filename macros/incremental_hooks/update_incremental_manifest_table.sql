{# Updates the incremental manifest table at the run end with the latest tstamp consumed per model #}
{% macro update_incremental_manifest_table(manifest_table, base_events_table, models) -%}

  {{ return(adapter.dispatch('update_incremental_manifest_table', 'fueled_utils')(manifest_table, base_events_table, models)) }}

{% endmacro %}

{% macro default__update_incremental_manifest_table(manifest_table, base_events_table, models) -%}

  {% if models %}

    {% set last_success_query %}
      select 
        b.model, 
        a.last_success 

      from 
        (select max(collector_tstamp) as last_success from {{ base_events_table }}) a,
        ({% for model in models %} select '{{model}}' as model {%- if not loop.last %} union all {% endif %} {% endfor %}) b

      where a.last_success is not null -- if run contains no data don't add to manifest
    {% endset %}

    merge into {{ manifest_table }} m
    using ( {{ last_success_query }} ) s
    on m.model = s.model
    when matched then
        update set last_success = greatest(m.last_success, s.last_success)
    when not matched then
        insert (model, last_success) values(model, last_success);

    {% if target.type == 'snowflake' %}
      commit;
    {% endif %}
    
  {% endif %}

{%- endmacro %}

{% macro postgres__update_incremental_manifest_table(manifest_table, base_events_table, models) -%}

  {% if models %}

    begin transaction;
      --temp table to find the greatest last_success per model.
      --this protects against partial backfills causing the last_success to move back in time.
      create temporary table fueled_models_last_success as (
        select
          a.model,
          greatest(a.last_success, b.last_success) as last_success

        from (

          select
            model,
            last_success

          from
            (select max(collector_tstamp) as last_success from {{ base_events_table }}) as ls,
            ({% for model in models %} select '{{model}}' as model {%- if not loop.last %} union all {% endif %} {% endfor %}) as mod

          where last_success is not null -- if run contains no data don't add to manifest

        ) a
        left join {{ manifest_table }} b
        on a.model = b.model
        );

      delete from {{ manifest_table }} where model in (select model from fueled_models_last_success);
      insert into {{ manifest_table }} (select * from fueled_models_last_success);

    end transaction;

    drop table fueled_models_last_success;
    
  {% endif %}

{%- endmacro %}
