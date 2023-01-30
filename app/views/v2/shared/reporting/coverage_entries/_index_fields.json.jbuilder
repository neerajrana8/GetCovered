json.extract!(coverage_entry,
  :id, :status,
  
  :reportable_type, :reportable_id,
  :reportable_category, :reportable_title, :reportable_description,
  
  :parent_id, :coverage_report_id,
  
  :total_units,

  :total_units_with_master_policy,
  :total_units_with_ho4_policy,
  :total_units_with_internal_policy,
  :total_units_with_external_policy,
  :total_units_with_no_policy,

  :percent_units_with_master_policy,
  :percent_units_with_ho4_policy,
  :percent_units_with_internal_policy,
  :percent_units_with_external_policy,
  :percent_units_with_no_policy,

  *(@show_more_fields.nil? ? [] : [

    :status

  ])
)
