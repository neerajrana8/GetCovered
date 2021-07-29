# Coverage Report Concern
# file: app/models/concerns/coverage_report.rb

module CoverageReport
  extend ActiveSupport::Concern

  def coverage_report
    report = {
      unit_count: insurables_units.count,
      occupied_count: occupied_insurables_count,
      covered_count: insurable_units_policies.count,
      occupied_covered_count: occupied_covered_count,
      master_policy_covered_count: insurables_covered_by_master_policy,
      policy_covered_count: nil,
      policy_internal_covered_count: insurable_units_policies.policy_in_system(true).count,
      policy_external_covered_count: insurable_units_policies.policy_in_system(false).count,
      cancelled_policy_count: cancelled_policy_count,
      in_force_policies_count: in_force_policies.count,
      in_force_in_system_policies_count: in_force_policies.policy_in_system(true).count,
      in_force_third_party_policies_count: in_force_policies.policy_in_system(false).count
    }

    report[:policy_covered_count] = report[:covered_count] - report[:master_policy_covered_count]
    report
  end

  private

  # select only commercial and residential units in children and base insurables
  def insurables_units
    if self.class == ::Insurable
      units.confirmed
    else # in other cases it's a relation insurables that contains units, buildings and communities
      insurables.units.confirmed
    end
  end

  def occupied_insurables_count
    insurables_units.joins(:leases).distinct.count
  end

  def occupied_covered_count
    occupied_ids = insurables_units.joins(:leases).distinct.pluck('insurables.id')
    Policy.joins(:insurables).where(insurables: { id: occupied_ids }).current.distinct.count
  end

  def insurables_covered_by_master_policy
    insurables_units
      .joins(:policies)
      .where(policies: { policy_type_id: PolicyType.master_coverages.ids })
      .distinct
      .count
  end

  def cancelled_policy_count
    Policy.joins(:insurables).
      where(insurables: { id: insurables_units.ids }).
      distinct.
      where.not(policy_type_id: PolicyType.master_coverages.ids).
      where(status: 'CANCELLED').
      count
  end

  def in_force_policies
    Policy.joins(:insurables).
      where(insurables: { id: insurables_units.ids }).
      distinct.
      where.not(policy_type_id: PolicyType.master_coverages.ids).
      where('expiration_date > ?', Time.zone.now).
      current
  end

  def insurable_units_policies
    Policy.joins(:insurables).where(insurables: { id: insurables_units.ids }).distinct.current
  end
end
