json.extract! unit_coverage_entry,
  :insurable_id,
  :street_address, :unit_number,
  :yardi_id,
  :lessee_count

json.coverage_status unit_coverage_entry.coverage_status(@determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
