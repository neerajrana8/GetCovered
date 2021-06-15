module MasterPolicies
  class AvailableUnitsQuery
    attr_accessor :master_policy

    def self.call(*args)
      new(*args).relation.order(Insurable.arel_table[:created_at].desc)
    end

    def initialize(master_policy, insurable_id = nil)
      @master_policy = master_policy
      @insurable_id = insurable_id
    end

    def relation
      result =
        Insurable.
          left_joins(:policy_insurables).
          units.
          where(insurables: { account_id: @master_policy.account }).
          where(condition)
      filters(result)
    end

    private

    def filters(relation)
      if @insurable_id.present?
        relation.where(insurables: {insurable_id: @insurable_id})
      else
        relation
      end
    end

    def insurables
      Insurable.
        left_joins(:policy_insurables).
        units.
        where(insurables: { account_id: @master_policy.account }).
        where(condition)
    end

    def condition
      <<-SQL
        #{without_policies} OR (insurables.id NOT IN (#{units_with_active_policies}) AND insurables.id NOT IN (#{units_with_current_leases}))
      SQL

    end

    def without_policies
      <<-SQL
        policy_insurables.policy_id IS NULL
      SQL
    end

    def units_with_active_policies
      Insurable.
        joins(:policies).
        units.
        where(insurables: { account_id: @master_policy.account }).
        where(active_policies_condition).
        select('insurables.id').
        to_sql
    end

    def units_with_current_leases
      Insurable.joins(:leases).
        units.
        where(insurables: { account_id: @master_policy.account }, leases: { status: 'current' }).
        select('insurables.id').
        to_sql
    end

    def active_policies_condition
      <<-SQL
        policies.policy_type_id IN (#{related_policy_types}) 
        AND policies.status IN (#{active_statuses})
        AND policies.expiration_date > '#{Time.zone.now}'
      SQL
    end

    def related_policy_types
      PolicyType::MASTER_MUTUALLY_EXCLUSIVE[@master_policy.policy_type_id].join(', ')
    end

    def active_statuses
      Policy.statuses.values_at('BOUND', 'BOUND_WITH_WARNING').join(', ')
    end
  end
end
