# StaffReporting
scope module: :staff_reporting, path: "reporting" do

  get :coverage_reports,
    to: "coverage_reports#index",
    via: "get",
    path: "coverage-reports/:coverage_report_id"
  get :coverage_entries,
    to: "coverage_entries#index",
    via: "get",
    path: "coverage-reports/:coverage_report_id/entries"
  get :unit_coverage_entries,
    to: "unit_coverage_entries#index",
    via: "get",
    path: "coverage-reports/:coverage_report_id/entries"

end
