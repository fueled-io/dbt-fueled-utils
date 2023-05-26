# fueled-utils-integration-tests

Integration test suite for the fueled-utils dbt package.

The `./scripts` directory contains several scripts. A selection of macros & materializations within this package require dedicated scripts to test, typically because they either:
- Need to be executed several times in order to be tested correctly i.e. an incremental materialization.
- To test they are throwing the correct compiler error. The error code is interpreted in bash.

Tests that require dedicated scripts are tagged with `requires_script` within the model for example [expected_combine_column_versions](models/utils/bigquery/expected_combine_column_versions.sql). This tag ensures they are excluded from the standard testing procedure:

```bash
dbt seed --full-refresh
dbt run --full-refresh --exclude tag:requires_script
dbt test --exclude tag:requires_script
``` 
