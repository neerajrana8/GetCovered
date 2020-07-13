module MasterPolicies
  class AvailableUnitsQuery
    attr_accessor :master_policy

    def self.call(*args)
      new(*args).relation.order(Insurable.arel_table[:created_at].desc)
    end

    def initialize(master_policy)
      @master_policy = master_policy
    end

    def relation
      Insurable.
        left_joins(:policy_insurables).
        units.
        where(insurables: { account_id: @master_policy.account }).
        where(condition)
    end

    private

    def insurables
      Insurable.
        left_joins(:policy_insurables).
        units.
        where(insurables: { account_id: @master_policy.account }).
        where(condition)
    end

    def condition
      <<-SQL
        #{without_policies} OR insurables.id NOT IN (#{units_with_active_policies})
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

    def active_policies_condition
      <<-SQL
        policies.policy_type_id IN (#{related_policy_types}) 
        AND policies.status NOT IN (#{not_active_statuses})
        AND policies.expiration_date > '#{Time.zone.now}'
      SQL
    end

    def related_policy_types
      [PolicyType::MASTER_COVERAGE_ID, PolicyType::RESIDENTIAL_ID].join(', ')
    end

    def not_active_statuses
      Policy.statuses.values_at('EXPIRED', 'CANCELLED', 'BIND_REJECTED').join(', ')
    end
  end
end
