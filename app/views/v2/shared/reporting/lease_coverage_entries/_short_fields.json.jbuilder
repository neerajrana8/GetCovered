json.extract! lease_coverage_entry,
  :id,
  :unit_coverage_entry_id,
  :lease_id,
  :status,
  :lessee_count,
  :yardi_id

json.coverage_status lease_coverage_entry.coverage_status(@determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
