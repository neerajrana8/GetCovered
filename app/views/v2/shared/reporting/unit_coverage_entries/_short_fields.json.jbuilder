json.extract! unit_coverage_entry,
  :id,
  :insurable_id,
  :street_address, :unit_number,
  :yardi_id,
  :lease_id,
  :lease_yardi_id,
  :lessee_count

json.coverage_status unit_coverage_entry.coverage_status(@determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
