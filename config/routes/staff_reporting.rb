# StaffReporting
scope module: :staff_reporting, path: "reporting" do

  post :coverage_reports,
    to: "coverage_reports#index",
    path: "coverage-reports/:coverage_report_id"
  post :coverage_entries,
    to: "coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/entries"
  post :unit_coverage_entries,
    to: "unit_coverage_entries#index",
    path: "coverage-reports/:coverage_report_id/unit-entries"
  
  post :latest_coverage_report,
    to: "coverage_reports#latest",
    path: "latest/coverage-report"

end
