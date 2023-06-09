{{
  config(
    tags = ['get_field'],
    )
}}

select
    {{fueled_utils.get_field('non_array_structure', 'col1')}} as nas_col1,
    {{fueled_utils.get_field('non_array_structure', 'col3')}} as nas_col3,
    {{fueled_utils.get_field('non_array_structure', 'col1', table_alias = 'a')}} as nas_ta_col1,
    {{fueled_utils.get_field('non_array_structure', 'col3', table_alias = 'a')}} as nas_ta_col3,
    {{fueled_utils.get_field('non_array_structure', 'col1', type = 'string')}} as nas_ty_col1,
    {{fueled_utils.get_field('non_array_structure', 'col3', type = 'string')}} as nas_ty_col3,
    {{fueled_utils.get_field('non_array_structure', 'col1', table_alias = 'a', type = 'string')}} as nas_ta_ty_col1,
    {{fueled_utils.get_field('non_array_structure', 'col3', table_alias = 'a', type = 'string')}} as nas_ta_ty_col3,

    {{fueled_utils.get_field('array_structure', 'col1', array_index = 0)}} as as_col1_ind0,
    {{fueled_utils.get_field('array_structure', 'col3', array_index = 0)}} as as_col3_ind0,
    {{fueled_utils.get_field('array_structure', 'col1', table_alias = 'a', array_index = 0)}} as as_ta_col1_ind0,
    {{fueled_utils.get_field('array_structure', 'col3', table_alias = 'a', array_index = 0)}} as as_ta_col3_ind0,
    {{fueled_utils.get_field('array_structure', 'col1', table_alias = 'a', type = 'string', array_index = 0)}} as as_ta_ty_col1_ind0,
    {{fueled_utils.get_field('array_structure', 'col3', table_alias = 'a', type = 'string', array_index = 0)}} as as_ta_ty_col3_ind0,
    {{fueled_utils.get_field('array_structure', 'col1', type = 'string', array_index = 0)}} as as_ty_col1_ind0,
    {{fueled_utils.get_field('array_structure', 'col3', type = 'string', array_index = 0)}} as as_ty_col3_ind0,
    {{fueled_utils.get_field('array_structure', 'col1', table_alias = 'a', type = 'string', array_index = 1)}} as as_ta_ty_col1_ind1,
    {{fueled_utils.get_field('array_structure', 'col3', table_alias = 'a', type = 'string', array_index = 1)}} as as_ta_ty_col3_ind1
from
    {{ ref('data_get_field') }} a
