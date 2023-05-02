json.extract! lease_coverage_entry,
  :id,
  :unit_coverage_entry_id,
  :lease_id,
  :status,
  :start_date,
  :end_date,
  :lessee_count,
  :yardi_id,
  :account_id,
  :report_time

json.coverage_status lease_coverage_entry.get_coverage_status(determinant: @determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
