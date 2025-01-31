# StaffReporting


scope module: :staff_reporting, path: "reporting" do

  # website

  get :web_file,
    to: "web#serve",
    path: "web/*file"

  # general utilities
  
  get :auth_check,
    to: "utilities#auth_check",
    path: "verify-login"
    
  get :owner_list,
    to: "utilities#owner_list",
    path: "owner-list"

  # for coverage reports

  post :coverage_reports,
    to: "coverage_reports#show",
    path: "coverage-reports/:coverage_report_id/show"
  post :coverage_entries,
    to: "coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/entries"
  post :unit_coverage_entries,
    to: "unit_coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/unit-entries"
  post :unit_coverage_entries,
    to: "lease_coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/lease-entries"
  post :lease_user_coverage_entries,
    to: "lease_user_coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/lease-user-entries"
  post :latest_coverage_report,
    to: "coverage_reports#latest",
    path: "latest/coverage-report"

  # for fake coverage reports

  post :latest_lease_report,
    to: "lease_coverage_entries#fake_report",
    path: "latest/lease-report"
  post :latest_lease_user_report,
    to: "lease_user_coverage_entries#fake_report",
    path: "latest/resident-report"

  # for policy reports
  
  post :policy_entries,
    to: "policy_entries#index",
    path: "policy-entries"
  post :policy_entries_expiring,
    to: "policy_entries#index",
    path: "policy-entries/recent/expiring",
    defaults: { special: "expiring" }
  post :policy_entries_expired,
    to: "policy_entries#index",
    path: "policy-entries/recent/expired",
    defaults: { special: "expired" }
  post :latest_policy_report,
    to: "policy_entries#fake_report",
    path: "latest/policy-report"

end
