module Insurables
  # Updates the ++covered++ and ++expanded_covered++ column for all insurables with policies or for the single insurable if it was passed
  class UpdateCoveredStatus < ActiveInteraction::Base
    object :insurable, default: nil
    # firstly this method updates all insurables with not active policies, after it sets `covered: true` for units
    # with at least one active policy
    def execute
      if insurable.present?
        update_insurable(insurable)
      else
        update_units
        update_buildings
        update_communities
      end
    end

    private

    def update_insurable(insurable)
      related_policy_types =
        case insurable.insurable_type_id
        when *InsurableType::UNITS_IDS
          unit_policy_types
        when *InsurableType::BUILDINGS_IDS
          building_policy_types
        when *InsurableType::COMMUNITIES_IDS
          community_policy_types
        end

      coverages_statuses =
        insurable.
          policies.
          where(active_policies_condition(related_policy_types)).
          select(:policy_type_id, 'array_agg(policies.id)').
          group(:policy_type_id).
          pluck(:policy_type_id, 'array_agg(policies.id)').
          to_h

      insurable.update(expanded_covered: coverages_statuses, covered: coverages_statuses.any?)
    end

    def update_units
      Insurable.units.each do |insurable|
        update_insurable(insurable)
      end
    end

    def update_buildings
      Insurable.buildings.each do |insurable|
        update_insurable(insurable)
      end
    end

    def update_communities
      Insurable.communities.each do |insurable|
        update_insurable(insurable)
      end
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

    def unit_policy_types
      PolicyType.where(master: false).ids
    end

    def community_policy_types
      PolicyType::MASTER_IDS
    end

    def building_policy_types
      PolicyType::MASTER_IDS
    end
  end
end
