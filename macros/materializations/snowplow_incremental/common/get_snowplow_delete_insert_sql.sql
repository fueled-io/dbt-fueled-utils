{% macro get_fueled_delete_insert_sql(target, source, unique_key, dest_cols_csv, predicates) -%}
  {{ adapter.dispatch('get_fueled_delete_insert_sql', 'fueled_utils')(target, source, unique_key, dest_cols_csv, predicates) }}
{%- endmacro %}

{% macro default__get_fueled_delete_insert_sql(target, source, unique_key, dest_cols_csv, predicates) -%}
  
    delete from {{ target }}
    where ({{ unique_key }}) in (
        select ({{ unique_key }})
        from {{ source }}
    )
    {% if predicates %} and {{ predicates | join(' and ') }} {% endif %};

    insert into {{ target }} ({{ dest_cols_csv }})
    (
        select {{ dest_cols_csv }}
        from {{ source }}
    );

{%- endmacro %}

{# dbt v0.21 enabled autocommit for Snowflake. Wrap in transaction. #}
{% macro snowflake__get_fueled_delete_insert_sql(target, source, unique_key, dest_cols_csv, predicates) -%}
  
    begin;
    {{ fueled_utils.default__get_fueled_delete_insert_sql(target, source, unique_key, dest_cols_csv, predicates) }}
    commit;

{%- endmacro %}
