#!/bin/bash

# Expected input:
# -d (database) target database for dbt

while getopts 'd:' opt
do
  case $opt in
    d) DATABASE=$OPTARG
  esac
done

echo "Test get_enabled_fueled_models: Untagged model"

OUTPUT=$(eval "dbt test --models test_get_enabled_fueled_models --target $DATABASE --vars \"{'tag_var': 'random_tag'}\"")
EXIT_CODE=$?

if [[ $OUTPUT == *"Fueled Warning: Untagged models referencing"* ]]; then
  UNTAGGED_MODEL_ERROR=true
fi

if [[ $UNTAGGED_MODEL_ERROR  && $EXIT_CODE==1 ]]; then
  echo "Pass: Untagged model error message raised"
else
  echo "Fail: Untagged model error message not raised"
  exit 1
fi

echo "Test get_enabled_fueled_models: All models"

eval "dbt test --models test_get_enabled_fueled_models --target $DATABASE" || exit 1;

echo "Test get_enabled_fueled_models: Subset of models"

# TODO: Use the dbt ls command instead of hardcoding. Issue is the model has to exist in the project. Models may well change in the int test dir.
eval "dbt test --models test_get_enabled_fueled_models --target $DATABASE --vars \"{'models_to_run': 'enabled_model_w_dependency non_fueled_model'}\"" || exit 1;

echo "Test get_enabled_fueled_models: All tests passed"


