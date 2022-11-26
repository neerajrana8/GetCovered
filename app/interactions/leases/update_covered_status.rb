module Leases
  # Updates the ++covered++ and ++expanded_covered++ column for all Leases with policies or for the single Lease if it was passed
  class UpdateCoveredStatus < ActiveInteraction::Base
    object :lease, default: nil
    # firstly this method updates all Leases with not active policies, after it sets `covered: true` for units
    # with at least one active policy
    def execute
      if lease.present?
        update_lease(lease)
      end
    end

    private

    def update_lease(lease)
      related_policy_types = PolicyType.where(master: false).ids

      coverages_statuses =
        lease.policies
             .where(active_policies_condition(related_policy_types))
             .select(:policy_type_id, 'array_agg(policies.id)')
             .group(:policy_type_id)
             .pluck(:policy_type_id, 'array_agg(policies.id)')
             .to_h

      lease.update(expanded_covered: coverages_statuses, covered: coverages_statuses.any?)
    end

    def active_policies_condition(related_policy_types)
      <<-SQL
        policies.policy_type_id IN (#{related_policy_types.join(', ')})
        AND policies.status IN (#{active_statuses.join(', ')})
        AND policies.effective_date <= '#{Time.zone.now}'
        AND policies.expiration_date > '#{Time.zone.now}'
      SQL
    end

    def active_statuses
      Policy.statuses.values_at(*Policy.active_statuses)
    end
  end
end
