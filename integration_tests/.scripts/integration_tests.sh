#!/bin/bash

# Expected input:
# -d (database) target database for dbt. Set to 'all' to test all supported databases.

while getopts 'd:' opt
do
  case $opt in
    d) DATABASE=$OPTARG
  esac
done

declare -a SUPPORTED_DATABASES=("bigquery" "databricks" "postgres" "redshift" "snowflake")

# set to lower case
DATABASE="$(echo $DATABASE | tr '[:upper:]' '[:lower:]')"

if [[ $DATABASE == "all" ]]; then
  DATABASES=( "${SUPPORTED_DATABASES[@]}" )
else
  DATABASES=$DATABASE
fi

for db in ${DATABASES[@]}; do

  echo "Fueled-utils integration tests: Seeding data"

  eval "dbt seed --target $db --full-refresh" || exit 1;

  echo "Fueled-utils integration tests: Run native dbt based tests"

  echo "Fueled-utils native dbt tests: Execute models"

  eval "dbt run --exclude tag:requires_script --target $db --full-refresh " || exit 1;

  echo "Fueled-utils native dbt tests: Test models"

  eval "dbt test --exclude tag:requires_script --target $db --store-failures" || exit 1;

  echo "Fueled utils integration tests: Run script based tests"

  echo "Fueled-utils integration tests: Testing get_successful_models"

  source "${BASH_SOURCE%/*}/test_get_successful_models.sh" -d $db || exit 1;

  echo "Fueled-utils integration tests: Testing materializations"

  source "${BASH_SOURCE%/*}/test_materializations.sh" -d $db -s false || exit 1; # don't re-seed

  echo "Fueled-utils integration tests: Testing get_enabled_fueled_models"

  source "${BASH_SOURCE%/*}/test_get_enabled_fueled_models.sh" -d $db || exit 1;

  echo "Fueled-utils integration tests: Testing fueled_delete_from_manifest"

  source "${BASH_SOURCE%/*}/test_fueled_delete_from_manifest.sh" -d $db || exit 1;

  echo "Fueled-utils integration tests: Testing return_limits_from_model"

  eval "dbt run-operation test_return_limits_from_models --target $db"  || exit 1;

  echo "Fueled-utils integration tests: Testing get_sde_or_context"

  eval "dbt run-operation test_get_sde_or_context --target $db"  || exit 1;

  echo "Fueled-utils integration tests: All tests passed for $db"

done
