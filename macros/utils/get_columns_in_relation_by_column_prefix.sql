{% macro get_columns_in_relation_by_column_prefix(relation, column_prefix) %}

  {# Prevent introspective queries during parsing #}
  {%- if not execute -%}
    {{ return('') }}
  {% endif %}

  {%- set columns = adapter.get_columns_in_relation(relation) -%}

  {# get_columns_in_relation returns uppercase cols for snowflake so uppercase column_prefix #}
  {%- set column_prefix = column_prefix.upper() if target.type == 'snowflake' else column_prefix -%}

  {%- set matched_columns = [] -%}

  {# add columns with matching prefix to matched_columns #}
  {% for column in columns %}
    {% if column.name.startswith(column_prefix) %}
      {% do matched_columns.append(column) %}
    {% endif %}
  {% endfor %}

  {% if matched_columns|length %}
    {{ return(matched_columns) }}
  {% else %}
    {{ exceptions.raise_compiler_error("Fueled: No columns found with prefix "~column_prefix) }}
  {% endif %}

{% endmacro %}
