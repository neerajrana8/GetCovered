json.extract! unit_coverage_entry,
  :id,
  :insurable_id,
  :street_address, :unit_number,
  :yardi_id,
  :occupied,
  :lease_yardi_id,
  :primary_lease_coverage_entry_id

json.coverage_status unit_coverage_entry.get_coverage_status(determinant: @determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
