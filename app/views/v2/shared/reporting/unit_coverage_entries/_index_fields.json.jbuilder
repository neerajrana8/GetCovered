json.extract! unit_coverage_entry,
  :id,
  :insurable_id, :report_time,
  :street_address, :unit_number,
  :yardi_id,
  :lessee_count, :lease_id, :lease_yardi_id


if @determinant
  json.coverage_status unit_coverage_entry.coverage_status(@determinant, expand_ho4: @expand_ho4, simplify: @simplify_status)
emd
