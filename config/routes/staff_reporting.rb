# StaffReporting
scope module: :staff_reporting, path: "reporting" do

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
  post :lease_user_coverage_entries,
    to: "lease_user_coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/lease-user-entries"
  post :latest_coverage_report,
    to: "coverage_reports#latest",
    path: "latest/coverage-report"

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
