{% docs __fueled_utils__ %}
{% raw %}

# fueled-utils

This package contains a mix of functionality to be used with the other Fueled dbt packages, or to be used within your own packages/projects.

Includes:

- Overwritten incremental materialization.
- Utils to assist with modeling Fueled data.
- Pre and post hooks to handle incremental processing of events.
- Various helper macros used throughout data modeling.

## Credits

This project started off as a mirror of Snowplow Analytics' [dbt-snowplow-utils](https://github.com/snowplow/dbt-snowplow-utils)

## Contents

**[Macros](#macros)**

1. [fueled-utils](#fueled-utils)
   1. [Contents](#contents)
   2. [Macros](#macros)
      1. [get\_columns\_in\_relation\_by\_column\_prefix (source)](#get_columns_in_relation_by_column_prefix-source)
      2. [combine\_column\_versions (source)](#combine_column_versions-source)
      3. [is\_run\_with\_new\_events (source)](#is_run_with_new_events-source)
      4. [fueled\_web\_delete\_from\_manifest (source)](#fueled_web_delete_from_manifest-source)
      5. [fueled\_mobile\_delete\_from\_manifest (source)](#fueled_mobile_delete_from_manifest-source)
      6. [get\_value\_by\_target (source)](#get_value_by_target-source)
      7. [n\_timedeltas\_ago (source)](#n_timedeltas_ago-source)
      8. [set\_query\_tag (source)](#set_query_tag-source)
      9. [get\_array\_to\_string (source)](#get_array_to_string-source)
      10. [get\_split\_to\_array (source)](#get_split_to_array-source)
      11. [get\_string\_agg (source)](#get_string_agg-source)
      12. [get\_sde\_or\_context (source)](#get_sde_or_context-source)
      13. [get\_field (source)](#get_field-source)
      14. [timestamp\_diff (source)](#timestamp_diff-source)
      15. [timestamp\_add (source)](#timestamp_add-source)
      16. [cast\_to\_tstamp (source)](#cast_to_tstamp-source)
      17. [to\_unixtstamp (source)](#to_unixtstamp-source)
      18. [current\_timestamp\_in\_utc (source)](#current_timestamp_in_utc-source)
      19. [unnest (source)](#unnest-source)
   3. [Materializations](#materializations)
      1. [Optimized incremental](#optimized-incremental)
      2. [BigQuery](#bigquery)
      3. [Snowflake](#snowflake)
      4. [Notes](#notes)
3. [Copyright and license](#copyright-and-license)


## Macros

There are many macros contained in this package, with the majority designed for use internally at Fueled.

There are however a selection that were intended for public use and that can assist you in modelling Fueled data. The documentation for these macros can be found below.

### get_columns_in_relation_by_column_prefix ([source](macros/utils/get_columns_in_relation_by_column_prefix.sql))

This macro returns an array of column objects within a relation that start with the given column prefix. This is useful when you have multiple versions of a column within a table and want to dynamically identify all versions.

**Arguments:**

- `relation`: The relation from which to search for matching columns.
- `column_prefix`: The column prefix to search for.

**Returns:**

- An array of [column objects][dbt-column-objects]. The name of each column can be accessed with the name property.

**Usage:**

```sql
{% set matched_columns = fueled_utils.get_columns_in_relation_by_column_prefix(
                          relation=ref('fueled_web_base_events_this_run'),
                          column_prefix='custom_context_1_0_'
                          ) %}

{% for column in matched_columns %}
  {{ column.name }}
{% endfor %}

# Renders to something like:
'custom_context_1_0_1'
'custom_context_1_0_2'
'custom_context_1_0_3'
```

The order of the matched columns is denoted by their ordinal position.

### combine_column_versions ([source](macros/utils/bigquery/combine_column_versions.sql))

*BigQuery Only.* This macro is designed primarily for combining versions of custom context or an unstructured event column from the Fueled events table in BigQuery.

As your schemas for such columns evolve, multiple versions of the same column will be created in your events table e.g. `custom_context_1_0_0`, `custom_context_1_0_1`. These columns contain nested fields i.e. are of a datatype `RECORD`. When modeling Fueled data it can be useful to combine or coalesce each nested field across all versions of the column for a continuous view over time. This macro mitigates the need to update your coalesce statement each time a new version of the column is created.

Fields can be selected using 4 methods:

- Select all fields. Default.
- Select by field name using the `required_fields` arg.
- Select all fields at a given level/depth of nesting e.g. all 1st level fields. Uses the `nested_level` arg.
- Select all fields, excluding specific versions using the `exclude_versions` arg.

By default any returned fields will be assigned an alias matching the field name e.g. `coalesce(<col_v2>.product, <col_v1>.product) as product`. For heavily nested fields, the alias will be field's path with `.` replaced with `_` e.g. for a field `product.size.height` will have an alias `product_size_height`. A custom alias can be supplied with the `required_fields` arg (see below).

**Arguments:**

- `relation`: The relation from which to search for matching columns.
- `column_prefix`: The column prefix to search for.
- `required_fields`: Optional. List of fields to return. For fields nested deeper than the 1st level specify the path using dot notation e.g. `product.name`. To use a custom field alias, pass a tuple containing the field name and alias e.g. `(<field_name>, <field_alias>)`.
- `nested_level`: Optional. The level from which to return fields e.g. `1` to return all 1st level fields. Behaviour can be changed to comparison using `level_filter` arg.
- `level_filter`: Default `equalto`. Accepted values `equalto`, `lessthan`, `greaterthan`. Used in conjunction with `nested_level` to determine which fields to return.
- `relation_alias`: Optional. The alias of the relation containing the column. If passed the alias will be prepended to the full path for each field e.g. `<relation_alias>.<column>.<field>`. Useful when your desired column occurs in multiple relations within your model.
- `include_field_alias`: Default `True`. Determines whether to included the field alias in the final coalesced field e.g. `coalesce(...) as <field_alias>`. Useful when using the field as part of a join.
- `array_index`: Default 0. If the column is of mode `REPEATED` i.e. an array, this determines the element to take. All Fueled context columns are arrays, typically with only a single element.
- `max_nested_level`: Default 15. Imposes a hard stop for recursions on heavily nested data.
- `exclude_versions`: Optional. List of versions to be excluded from column coalescing. Versions should be provided as an array of strings in snake case (`['1_0_0']`)

**Returns:**

- An array, with each item being a string of coalesced paths to a field across each version of the column. The order of the coalesce is determined by the version of the column, with the latest taking precedent.

**Usage:**

The following examples assumes two 'product' context columns with the following schemas:

![Example nested fields](./assets/nested_fields.png)

**All fields**

```sql
{%- set all_fields = fueled_utils.combine_column_versions(
                                relation=ref('fueled_web_base_events_this_run'),
                                column_prefix='product_v'
                                ) -%}

select
{% for field in all_fields %}
  {{field}} {%- if not loop.last %},{% endif %}
{% endfor %}

# Renders to:
select
  coalesce(product_v2[safe_offset(0)].name, product_v1[safe_offset(0)].name) as name,
  coalesce(product_v2[safe_offset(0)].specs, product_v1[safe_offset(0)].specs) as specs,
  coalesce(product_v2[safe_offset(0)].specs.power_rating, product_v1[safe_offset(0)].specs.power_rating) as specs_power_rating,
  coalesce(product_v2[safe_offset(0)].specs.volume) as specs_volume,
  coalesce(product_v2[safe_offset(0)].specs.accessories, product_v1[safe_offset(0)].specs.accessories) as specs_accessories
```

Note fields within `accessories` are not unnested as `accessories` is of mode `REPEATED`. See limitations section below.

**Fields filtered by name**

```sql
{%- set required_fields = fueled_utils.combine_column_versions(
                                relation=ref('fueled_web_base_events_this_run'),
                                column_prefix='product_v',
                                required_fields=['name', ('specs.power_rating', 'product_power_rating')]
                                ) -%}

select
{% for field in required_fields %}
  {{field}} {%- if not loop.last %},{% endif %}
{% endfor %}

# Renders to:
select
  coalesce(product_v2[safe_offset(0)].name, product_v1[safe_offset(0)].name) as name,
  coalesce(product_v2[safe_offset(0)].specs.power_rating, product_v1[safe_offset(0)].specs.power_rating) as product_power_rating
```

Note we have renamed the power rating field by passing a tuple of the field name and desired field alias.

**Fields filtered by level**

```sql
{%- set fields_by_level = fueled_utils.combine_column_versions(
                                relation=ref('fueled_web_base_events_this_run'),
                                column_prefix='product_v',
                                nested_level=1
                                ) -%}

select
{% for field in fields_by_level %}
  {{field}} {%- if not loop.last %},{% endif %}
{% endfor %}

# Renders to:
select
  coalesce(product_v2[safe_offset(0)].name, product_v1[safe_offset(0)].name) as name,
  coalesce(product_v2[safe_offset(0)].specs, product_v1[safe_offset(0)].specs) as specs
```

**Limitations**

- If a field is of the data type `RECORD` and a mode `REPEATED`, i.e. an array of structs, it's sub/nested fields will not be unnested.

### is_run_with_new_events ([source](macros/utils/is_run_with_new_events.sql))

This macro is designed for use with Fueled data modelling packages like `fueled-web`. It can be used in any incremental models, to effectively block the incremental model from being updated with old data which it has already consumed. This saves cost as well as preventing historical data from being overwritten with partially complete data (due to a batch back-fill for instance).

The macro utilizes the `fueled_[platform]_incremental_manifest` table to determine whether the model from which the macro is called, i.e. `{{ this }}`, has already consumed the data in the given run. If it has, it returns `false`. If the data in the run contains new data, `true` is returned.

**Arguments:**

- `package_name`: The modeling package name i.e. `fueled-mobile`.

**Returns:**

- Boolean. `true` if the run contains new events previously not consumed by `this`, `false` otherwise.

**Usage:**

```sql
{{
  config(
    materialized='incremental',
    unique_key='screen_view_id',
    upsert_date_key='start_tstamp'
  )
}}

select
  ...

from {{ ref('fueled_mobile_base_events_this_run' ) }}
where {{ fueled_utils.is_run_with_new_events('fueled_mobile') }} --returns false if run doesn't contain new events.
```

### fueled_web_delete_from_manifest ([source](macros/utils/fueled_delete_from_manifest.sql))

The `fueled-web` package makes use of a centralised manifest system to record the current state of the package. There may be times when you want to remove the metadata associated with particular models from the manifest, for instance to replay events through a particular model.

This can be performed as part of the run-start operation of the fueled-web package, as described in the [docs][fueled-web-docs]. You can however perform this operation independently using the `fueled_web_delete_from_manifest` macro.

**Arguments:**

- `models`: Either an array of models to delete, or a string for a single model.

**Usage:**

```bash
dbt run-operation fueled_web_delete_from_manifest --args "models: ['fueled_web_page_views','fueled_web_sessions']"
# or
dbt run-operation fueled_web_delete_from_manifest --args "models: fueled_web_page_views"
```

### fueled_mobile_delete_from_manifest ([source](macros/utils/fueled_delete_from_manifest.sql))

The `fueled-mobile` package makes use of a centralised manifest system to record the current state of the package. There may be times when you want to remove the metadata associated with particular models from the manifest, for instance to replay events through a particular model.

This can be performed as part of the run-start operation of the fueled-mobile package, as described in the [docs][fueled-mobile-docs]. You can however perform this operation independently using the `fueled_mobile_delete_from_manifest` macro.

**Arguments:**

- `models`: Either an array of models to delete, or a string for a single model.

**Usage:**

```bash
dbt run-operation fueled_mobile_delete_from_manifest --args "models: ['fueled_mobile_screen_views','fueled_mobile_sessions']"
# or
dbt run-operation fueled_mobile_delete_from_manifest --args "models: fueled_mobile_screen_views"
```

### get_value_by_target ([source](macros/utils/get_value_by_target.sql))

This macro is designed to dynamically return values based on the target (`target.name`) you are running against. Your target names are defined in your [profiles.yml](https://docs.getdbt.com/reference/profiles.yml) file. This can be useful for dynamically changing variables within your project, depending on whether you are running in dev or prod.

**Arguments:**

- `dev_value`: The value to be returned if running against your dev target, as defined by `dev_target_name`.
- `default_value`: The default value to return, if not running against your dev target.
- `dev_target_name`: Default: `dev`. The name of your dev target as defined in your `profiles.yml` file.

**Usage:**

```yml
# dbt_project.yml
...
vars:
  fueled_web:
    fueled__backfill_limit_days: "{{ fueled_utils.get_value_by_target(dev_value=1, default_value=30, dev_target_name='dev') }}"
```

**Returns:**

- `dev_value` if running against your dev target, otherwise `default_value`.

### n_timedeltas_ago ([source](macros/utils/n_timedeltas_ago.sql))

This macro takes the current timestamp and subtracts `n` units, as defined by the `timedelta_attribute`, from it. This is achieved using the Python datetime module, rather than querying your database.

**Arguments:**

- `n`: The number of timedeltas to subtract from the current timestamp.
- `timedelta_attribute`: The type of units to subtract. This can be any valid attribute of the [timedelta](https://docs.python.org/3/library/datetime.html#timedelta-objects) object.

**Usage:**

```sql
{{ fueled_utils.n_timedeltas_ago(1, 'weeks') }}
```

**Returns:**

- Current timestamp minus `n` units.

By combining this with the `get_value_by_target` macro, you can dynamically set dates depending on your environment:

```yml
# dbt_project.yml
...
vars:
  fueled_mobile:
    fueled__start_date: "{{ fueled_utils.get_value_by_target(
                                      dev_value=fueled_utils.n_timedeltas_ago(1, 'weeks'),
                                      default_value='2020-01-01',
                                      dev_target_name='dev') }}"
```

### set_query_tag ([source](macros/utils/set_query_tag.sql))

This macro takes a provided statement as argument and generates the SQL command to set this statement as the query_tag for Snowflake databases, and does nothing otherwise. It can be used to safely set the query_tag regardless of database type.

**Arguments:**

- `statement`: The query_tag that you want to set in your Snowflake session.


**Usage:**

```sql
{{ fueled_utils.set_query_tag('fueled_query_tag') }}
```

**Returns:**

- The SQL statement which will update the query tag in Snowflake, or nothing in other databases.


### get_array_to_string ([source](macros/utils/cross_db/get_array_to_string.sql))

This macro takes care of harmonizing cross-db functions that flatten an array to a string. It takes an array column, a column prefix and a delimiter as an argument.


**Usage:**

```sql
{{ fueled_utils.get_array_to_string('array_column', 'column_prefix', 'delimiter') }}
```

**Returns:**

 - The database equivalent of a string datatype with the maximum allowed length
### get_split_to_array ([source](macros/utils/cross_db/get_split_to_array.sql))

This macro takes care of harmonizing cross-db functions that create an array out of a string. It takes a string column, a column prefix and a delimiter as an argument.


**Usage:**

```sql
{{ fueled_utils.get_split_to_array('string_column', 'column_prefix', 'delimiter') }}
```

**Returns:**

- An array field.

### get_string_agg ([source](macros/utils/cross_db/get_string_agg.sql))

This macro takes care of harmonizing cross-db `list_agg`, `string_agg` type functions. These are aggregate functions that take all expressions from rows and concatenate them into a single string.

A base column and its prefix have to be provided, the separator is optional (default is ',').

By default ordering is defined by sorting the base column in ascending order. If you wish to order on a different column, the `order_by_column` and `order_by_column_prefix` have to be provided. If you wish to order in descending order, then set `order_desc` to `true`.

In case the field used for sorting happens to be of numeric value (regardless of whether it is stored as a string or as a numeric type) the `sort_numeric` parameter should be set to true, which takes care of conversions from sting to numeric if needed.

There is also an optional boolean parameter called `is_distinct` which, when enabled, takes care of deduping individual elements within the array.

**Usage:**

```sql
{{ fueled_utils.get_string_agg('base_column', 'column_prefix', ';', 'order_by_col', sort_numeric=true, order_by_column_prefix='order_by_column_prefix', is_distict=True, order_desc=True) }}

```

**Returns:**

- The database equivalent of a string datatype with the maximum allowed length

### get_sde_or_context ([source](macros/utils/get_context_or_sde.sql))

This macro exists for Redshift and Postgres users to more easily select their self-describing event and context tables and apply de-duplication before joining onto their (already de-duplicated) events table. The `root_id` and `root_tstamp` columns are by default returned as `schema_name_id` and `schema_name_tstamp` respectively, where `schema_name` is the value in the `schema_name` column of the table. In the case where multiple entities may be sent in the context (e.g. products in a search results), you should set the `single_entity` argument to `false` and use an additional criteria in your join (see [the fueled docs](https://docs.fueled.io/docs/modeling-your-data/modeling-your-data-with-dbt/dbt-advanced-usage/dbt-duplicates/) for further details).

Note that it is the responsibility of the user to ensure they have no duplicate names when using this macro multiple times or when a schema column name matches a column already in the events table. In this case the `prefix` argument should be used and aliasing applied to the output.

**Usage:**

With at most one entity per context:
```sql
with {{ fueled_utils.get_sde_or_context('atomic', 'nl_basjes_yauaa_context_1', "'2023-01-01'", "'2023-02-01'")}}

select
...
from my_events_table a
left join nl_basjes_yauaa_context_1 b on 
    a.event_id = b.yauaa_context__id 
    and a.collector_tstamp = b.yauaa_context__tstamp
```
With the possibility of multiple entities per context, your events table must already be de-duped but still have a field with the number of duplicates:
```sql
with {{ fueled_utils.get_sde_or_context('atomic', 'nl_basjes_yauaa_context_1', "'2023-01-01'", "'2023-02-01'", single_entity = false)}}

select
...,
count(*) over (partition by a.event_id) as duplicate_count
from my_events_table a
left join nl_basjes_yauaa_context_1 b on 
    a.event_id = b.yauaa_context__id 
    and a.collector_tstamp = b.yauaa_context__tstamp
    and mod(b.yauaa_context__index, a.duplicate_count) = 0
```

**Returns:**

CTE sql for deduplicated records from the schema table, without the schema details columns. The final CTE is the name of the original table. e.g.

```sql
dd_my_context_table as (
  select ..., ... as dedupe_index from my_schema.my_context_table
),

my_context_table as (
  select ... from dd_my_context_table where dedupe_index = 1
)
```

With at most one entity per context:
```sql
dd_my_context_table as (
  select ..., ... as dedupe_index from my_schema.my_context_table
),

my_context_table as (
  select ..., root_id as my_context_table__id, root_tstamp as my_context_table__tstamp from dd_my_context_table where dedupe_index = 1
)
```
With the possibility of multiple entities per context, your events table must already be de-duped but still have a field with the number of duplicates:
```sql
dd_my_context_table as (
  select ..., ... as dedupe_index from my_schema.my_context_table
),

my_context_table as (
  select ..., , root_id as my_context_table__id, root_tstamp as my_context_table__tstamp, ... as my_context_table__index from dd_my_context_table
)
```

### get_field ([source](macros/utils/cross_db/get_field.sql))

This macro exists to make it easier to extract a field from our `unstruct_` and `contexts_` type columns for users in Snowflake, Databricks, and BigQuery (although you may prefer to use [`combine_column_versions`](#combine_column_versions-source) for BigQuery, as this manages multiple context versions and allows for extraction of multiple fields at the same time). The macro can handle type casting and selecting from arrays.

**Returns:**

sql line to select the field specified from the column

**Usage:**


Extracting a single field
```sql

select
{{ fueled_utils.get_field(column_name = 'contexts_nl_basjes_yauaa_context_1', 
                            field_name = 'agent_class', 
                            table_alias = 'a',
                            type = 'string',
                            array_index = 0)}} as yauaa_agent_class
from 
    my_events_table a

```

Extracting multiple fields
```sql

select
{% for field in [('field1', 'string'), ('field2', 'numeric'), ...] %}
  {{ fueled_utils.get_field(column_name = 'contexts_nl_basjes_yauaa_context_1', 
                            field_name = field[0], 
                            table_alias = 'a',
                            type = field[1],
                            array_index = 0)}} as {{ field[0] }}
{% endfor %}

from 
    my_events_table a

``````


### timestamp_diff ([source](macros/utils/cross_db/timestamp_functions.sql))

This macro mimics the utility of the dbt_utils version however for BigQuery it ensures that the timestamp difference is calculated, similar to the other DB engines which is not the case in the dbt_utils macro. This macro calculates the difference between two dates. Note: The datepart argument is database-specific.

**Arguments:**

- `first_stamp`: The earlier timestamp to subtract by
- `second_tstamp`: The later timestamp to subtract from
- `datepart`: The unit of time that the result is denoted it

**Usage:**

```sql
{{ fueled_utils.timestamp_diff('2022-01-10 10:23:02', '2022-01-14 09:40:56', 'day') }}
```

**Returns:**

- The timestamp difference between two fields denoted in the requested unit

### timestamp_add ([source](macros/utils/cross_db/timestamp_functions.sql))

This macro mimics the utility of the dbt_utils version however for BigQuery it ensures that the timestamp difference is calculated, similar to the other DB engines which is not the case in the dbt_utils macro. This macro adds a date/time interval to the supplied date/timestamp. Note: The datepart argument is database-specific.


**Arguments:**

- `datepart`: The date/time type of interval to be added
- `interval`: The amount of time of the datepart to be added
- `tstamp`: The timestamp to add the interval to

**Usage:**

```sql
{{ fueled_utils.timestamp_add('day', 5, '2022-02-01 10:05:32') }}
```

**Returns:**

- The new timestamp that results in adding the interval to the provided timestamp.

### cast_to_tstamp ([source](macros/utils/cross_db/timestamp_functions.sql))

This macro casts a column to a timestamp across databases. It is an adaptation of the `type_timestamp()` macro from dbt-core.

**Arguments:**

- `tstamp_literal`: The column that is to be cast to a tstamp data type

**Usage:**

```sql
{{ fueled_utils.cast_to_tstamp('events.collector_tstamp') }}
```

**Returns:**

- The field as a timestamp

### to_unixtstamp ([source](macros/utils/cross_db/timestamp_functions.sql))

This macro casts a column to a unix timestamp across databases.

**Arguments:**

- `tstamp`: The column that is to be cast to a unix timestamp

**Usage:**

```sql
{{ fueled_utils.to_unixtstamp('events.collector_tstamp') }}
```

**Returns:**

- The field as a unix timestamp

### current_timestamp_in_utc ([source](macros/utils/cross_db/timestamp_functions.sql))

This macro returns the current timestamp in UTC.

**Usage:**

```sql
{{ fueled_utils.current_timestamp_in_utc() }}
```

**Returns:**
The current timestamp in UTC.


### unnest ([source](macros/utils/cross_db/unnest.sql))

This macro takes care of unnesting of arrays regardles of the data warehouse. An id column and the colum to base the unnesting off of needs to be specified as well as a field alias and the source table.


**Usage:**

```sql
{{ fueled_utils.unnest('id_column', 'array_to_be_unnested', 'field_alias', 'source_table') }}
```

**Returns:**

- The database equivalent of a string datatype with the maximum allowed length
## Materializations

### Optimized incremental

This package provides an enhanced version of the standard incremental materialization. This builds upon the out-of-the-box incremental materialization provided by dbt, by limiting the length of the table scans on the destination table. This improves both performance and reduces cost. The following methodology is used to calculate the limit of the table scan:

- The minimum date is found in the `tmp_relation`, based on the `upsert_date_key`
- By default, 30 days are subtracted from this date. This is set by `fueled__upsert_lookback_days`. We found when modeling Fueled data, having this look-back period of 30 days can help minimise the chance of introducing duplicates in your destination table. Reducing the number of look-back days will improve performance further but increase the risk of duplicates.
- The look-back can be disabled altogether, by setting `disable_upsert_lookback=true` in your model's config (see below). This is not recommended for most use cases.

To enable this optimized version you must add `fueled_optimize=true` to the config of any model using it, and add the following once to your `dbt_project.yml` file:

```yml
dispatch:
  - macro_namespace: dbt
    search_order: ['fueled_utils', 'dbt']
```

This optimization adds an additional `predicate`, based on the logic above, to the per-warehouse sql generated by dbt, and we use the [default incremental strategy](https://docs.getdbt.com/docs/build/incremental-models#about-incremental_strategy) for each warehouse.

Because we only overwrite the `get_merge_sql`/`get_delete_insert_merge_sql` this means all options and features of the standard incremental materialization are available, including `on_schema_change` and `incremental_predicates`.

Each config must contain, in addition to `fueled_optimize`, an `upsert_date_key` and a `unique_key`. We support Snowflake, BigQuery, Redshift, Postgres, Spark, and Databricks, however some warehouses have some additional config options that we recommend using to get the most out of the optimization. 

### BigQuery

For BigQuery it is advised (and required for the optimization to work) to add a `partition_by` to the config.

**Usage:**

```sql
{{
  config(
    materialized='incremental',
    unique_key='page_view_id', # Required: the primary key of your model
    upsert_date_key='start_tstamp', # Required: The date key to be used to calculate the limits
    partition_by = fueled_utils.get_value_by_target_type(bigquery_val={
      "field": "start_tstamp",
      "data_type": "timestamp",
      "granularity": "day" # Only introduced in dbt v0.19.0+. Defaults to 'day' for dbt v0.18 or earlier
    }) # Adds partitions to destination table.
  )
}}
```

### Snowflake

During testing we found that providing the `upsert_date_key` as a cluster key results in more effective partition pruning. This does add overhead however as the dataset needs to be sorted before being upserted. In our testing this was a worthwhile trade off, reducing overall costs. Your mileage may vary, as variables like row count can affect this.

**Usage:**

```sql
{{
  config(
    materialized='incremental',
    unique_key='page_view_id', # Required: the primary key of your model
    upsert_date_key='start_tstamp', # Required: The date key to be used to calculate the limits
    cluster_by='to_date(start_tstamp)' # Optional.
  )
}}
```

### Notes

- `fueled__upsert_lookback_days` defaults to 30 days. If you set `fueled__upsert_lookback_days` to too short a period, duplicates can occur in your incremental table.

# Copyright and license

The fueled-utils package is based upon Snowplow Analytic's original Copyright 2021-2022.

Licensed under the [Apache License, Version 2.0][license] (the "License");
you may not use this software except in compliance with the License.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[license]: http://www.apache.org/licenses/LICENSE-2.0

# Significant Changes

Snowplow's dbt-snowplow-util package has been mirrored by Fueled to work with Fueled's base event structures.

{% endraw %}
{% enddocs %}