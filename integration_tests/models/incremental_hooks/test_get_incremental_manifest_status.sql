
{%- set all_models = fueled_utils.get_incremental_manifest_status(ref('data_get_incremental_manifest_status'), ['a','b','c']) -%}
{%- set partial_models = fueled_utils.get_incremental_manifest_status(ref('data_get_incremental_manifest_status'), ['b','d']) -%}

select
  'all model_in_run exist in manifest' as test_case,
  {{ fueled_utils.cast_to_tstamp(all_models[0]) }} as min_last_success,
  {{ fueled_utils.cast_to_tstamp(all_models[1]) }} as max_last_success,
  {{all_models[2]}} as models_matched_from_manifest,
  {{all_models[3]}} as has_matched_all_models

union all

select
  'some model_in_run exist in manifest' as test_case,
  {{ fueled_utils.cast_to_tstamp(partial_models[0]) }} as min_last_success,
  {{ fueled_utils.cast_to_tstamp(partial_models[1]) }} as max_last_success,
  {{partial_models[2]}} as models_matched_from_manifest,
  {{partial_models[3]}} as has_matched_all_models
