module Insurables
  # Updates the ++covered++ column for all units with policies or for the single insurable if it was passed
  class UpdateCoveredStatus < ActiveInteraction::Base
    object :insurable, default: nil
    # firstly this method updates all insurables with not active policies, after it sets `covered: true` for units
    # with at least one active policy
    def execute
      if insurable.present?
        update_insurable
      else
        update_all_units
      end
    end

    private

    def update_insurable
      coverage_status = insurable.policies.where(active_policies_condition).any?
      insurable.update(covered: coverage_status)
    end

    def update_all_units
      not_covered_insurables.update_all(covered: false)
      covered_insurables.update_all(covered: true)
    end

    # We need only units with policies
    def base_query
      Insurable.
        joins(:policies).
        where(insurables: { insurable_type_id: InsurableType::UNITS_IDS })
    end

    def covered_insurables
      base_query.where(active_policies_condition)
    end

    def not_covered_insurables
      base_query.where.not(active_policies_condition)
    end

    def active_policies_condition
      <<-SQL
        policies.policy_type_id IN (#{related_policy_types})
        AND policies.status IN (#{active_statuses})
        AND policies.effective_date <= '#{Time.zone.now}'
        AND policies.expiration_date > '#{Time.zone.now}'
      SQL
    end

    def related_policy_types
      [PolicyType::MASTER_COVERAGE_ID, PolicyType::RESIDENTIAL_ID].join(', ')
    end

    def active_statuses
      Policy.statuses.values_at('BOUND', 'BOUND_WITH_WARNING').join(', ')
    end
  end
end
