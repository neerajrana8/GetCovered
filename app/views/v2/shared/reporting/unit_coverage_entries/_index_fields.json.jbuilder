json.extract! unit_coverage_entry,
  :id,
  :insurable_id, :report_time,
  :street_address, :unit_number,
  :yardi_id,
  :occupied,
  :lease_yardi_id,
  :primary_lease_coverage_entry_id


if @determinant
  json.coverage_status unit_coverage_entry.coverage_status(@determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
emd
