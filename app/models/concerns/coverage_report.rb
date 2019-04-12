# Coverage Report Concern
# file: app/models/concerns/coverage_report.rb

module CoverageReport
  extend ActiveSupport::Concern

  def coverage_report
    report = {
      unit_count: units.count,
      occupied_count: units.occupied.count,
      covered_count: units.covered.count,
      master_policy_covered_count: units.covered_by_master_policy.count,
      policy_covered_count: nil,
      policy_internal_covered_count: policies.current.in_system?(true).count,
      policy_external_covered_count: policies.current.in_system?(false).count
    }
    report[:policy_covered_count] = report[:covered_count] - report[:master_policy_covered_count]
    report[:policy_external_covered_count] = report[:policy_covered_count] - report[:policy_internal_covered_count]
    return(report)
  end
end
