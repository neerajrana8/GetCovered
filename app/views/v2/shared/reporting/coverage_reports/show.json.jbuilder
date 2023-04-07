json.partial! 'v2/shared/reporting/coverage_reports/fields.json.jbuilder',
  coverage_report: @coverage_report

json.manifest @coverage_report.manifest
