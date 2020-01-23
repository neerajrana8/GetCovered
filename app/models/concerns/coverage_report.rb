# Coverage Report Concern
# file: app/models/concerns/coverage_report.rb

module CoverageReport
  extend ActiveSupport::Concern

  def coverage_report
    report = {
      unit_count: insurables_units.count,
      occupied_count: occupied_insurables_count,
      covered_count: insurable_units_policies.count,
      master_policy_covered_count: insurables_covered_by_master_policy,
      policy_covered_count: nil,
      policy_internal_covered_count: insurable_units_policies.policy_in_system(true).count,
      policy_external_covered_count: insurable_units_policies.policy_in_system(false).count,
      cancelled_policy_count: cancelled_policy_count
    }

    report[:policy_covered_count] = report[:covered_count] - report[:master_policy_covered_count]
    report
  end

  private

  # select only commercial and residential units in children and base insurables
  def insurables_units
    insurable_units_ids = insurables.where(insurable_type_id: InsurableType::UNITS_IDS).ids
    children_units_ids = []
    insurables.where.not(insurable_type_id: InsurableType::UNITS_IDS).each do |insurable|
      children_units_ids |= insurable.units.pluck(:id)
    end
    Insurable.where(id: insurable_units_ids | children_units_ids) # prevent duplication
  end

  def occupied_insurables_count
    insurables_units.joins(:leases).distinct.count
  end

  def insurables_covered_by_master_policy
    insurables_units
      .joins(:policies)
      .where(policies: { policy_type_id: PolicyType.master_policies.ids })
      .distinct
      .count
  end

  def cancelled_policy_count
    Policy.joins(:insurables).
      where(insurables: { id: insurables_units.ids }).
      distinct.
      where.not(policy_type_id: PolicyType.master_policies.ids).
      where(status: 'CANCELLED').
      count
  end

  def insurable_units_policies
    Policy.joins(:insurables).where(insurables: { id: insurables_units.ids }).distinct.current
  end
end
