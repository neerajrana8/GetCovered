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
        joins(left_join_policies).
        units.
        where(insurables: { account_id: @master_policy.account }).
        where(condition)
    end

    private

    def condition
      "#{without_policies} OR #{with_not_related_policies} OR #{with_not_active_related_policies}"
    end

    def without_policies
      <<-SQL
        policies.id IS NULL
      SQL
    end

    def with_not_related_policies
      <<-SQL
        policies.policy_type_id NOT IN (#{related_policy_types})
      SQL
    end

    def with_not_active_related_policies
      <<-SQL
        policies.policy_type_id IN (#{related_policy_types}) AND (
          policies.expiration_date < '#{Time.zone.now}' OR 
          policies.cancellation_date_date < '#{Time.zone.now}' OR 
          policies.status IN (#{not_active_statuses})
        )
      SQL
    end

    def left_join_policies
      <<-SQL
        LEFT JOIN policy_insurables ON policy_insurables.insurable_id = insurables.id
        LEFT JOIN policies ON policies.id = policy_insurables.policy_id
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
