class InsurableData
  class Refresh < ActiveInteraction::Base
    object :insurable

    def execute
      if insurable.insurable_data.present?
        insurable.insurable_data.update(new_data)
      else
        InsurableData.create(new_data.merge(insurable: insurable))
      end
    end

    private

    def new_data
      {
        total_units: total_units,
        uninsured_units: uninsured_units,
        expiring_policies: expiring_policies
      }
    end

    def total_units
      insurable.units_relation.count
    end

    def uninsured_units
      without_policies = insurable.
        units_relation.
        joins('LEFT JOIN policy_insurables ON policy_insurables.id = insurables.id').
        where(policy_insurables: { id: nil }).select('insurables.id').
        distinct.count

      with_inactive_policies = insurable.
        units_relation.
        joins(:policies).
        where(policies: { status: Policy.active_statuses }).
        select('insurables.id').
        distinct.count

      without_policies + with_inactive_policies
    end

    def expiring_policies
      insurable.
        units_relation.
        joins(:policies).
        where(policies: { status: Policy.active_statuses }).
        where('policies.expiration_date < ?', Time.zone.now + 1.month).
        select('insurables.id').
        distinct.count
    end
  end
end
