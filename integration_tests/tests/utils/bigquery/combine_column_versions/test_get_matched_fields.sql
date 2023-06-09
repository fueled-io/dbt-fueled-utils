{{ config(enabled=(target.type == 'bigquery' | as_bool()) )}}

{% set tests_yml %}
  tests:
    - fields:
      - field_name: 'a'
        nested_level: 1
      required_field_names: []
      nested_level: Null
      expected:
      - field_name: 'a'
        nested_level: 1
    - fields:
      - field_name: 'a'
        nested_level: 1
      - field_name: 'b'
        nested_level: 2
      required_field_names: []
      nested_level: 2
      expected:
      - field_name: 'b'
        nested_level: 2
    - fields:
      - field_name: 'a'
        nested_level: 1
      - field_name: 'b'
        nested_level: 2
      required_field_names: ['a', 'c']
      nested_level: Null
      expected:
      - field_name: 'a'
        nested_level: 1
{% endset %}

{% set tests = fromyaml(tests_yml)['tests'] %}

with prep as (
{% for test in tests %}
  {# accepted values of level_filter are tested elsewhere. Keep constant for this test #}
  {%- set actual = fueled_utils.get_matched_fields(
                                                    fields=test.fields,
                                                    required_field_names=test.required_field_names,
                                                    nested_level=test.nested_level,
                                                    level_filter='equalto'
                                                    )-%}
  {%- set expected = test.expected -%}
  select "{{ actual}}" as actual, "{{ expected }}" as expected
  {% if not loop.last %} union all {% endif %}
{% endfor %}
)

select * 
from prep
where actual != expected
