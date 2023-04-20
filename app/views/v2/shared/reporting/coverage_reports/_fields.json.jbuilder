json.extract!(coverage_report,
  :id, :report_time,
  *(@show_more_fields.nil? ? [] : [
    :coverage_determinant, :completed_at,
    :status, :errors,
    :owner_type, :owner_id
  ])
)
