json.extract! lease_user_coverage_entry,
  :id, :yardi_id, :email, :first_name, :last_name, :lessee, :current, :policy_number, :account_id, :report_time

json.coverage_status lease_user_coverage_entry.coverage_status(expand_ho4: @expand_ho4, simplify: @simplify_status)
