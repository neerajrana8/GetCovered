module MasterPolicies
  class AvailableTopInsurablesQuery
    attr_accessor :master_policy

    def self.call(*args)
      new(*args).relation.order(Insurable.arel_table[:created_at].desc)
    end

    def initialize(master_policy, insurables_type)
      @master_policy = master_policy
      @insurables_type = insurables_type
    end

    def relation
      Insurable.
        left_joins(:policy_insurables).
        send(@insurables_type).
        where(insurables: { account_id: @master_policy.account }).
        where(condition).
        where.not(id: @master_policy.insurables.communities_and_buildings.ids)
    end

    private

    def insurables
      Insurable.
        left_joins(:policy_insurables).
        send(@insurables_type).
        where(insurables: { account_id: @master_policy.account }).
        where(condition)
    end

    def condition
      <<-SQL
        #{without_policies} OR (insurables.id NOT IN (#{insurables_with_active_policies}))
      SQL

    end

    def without_policies
      <<-SQL
        policy_insurables.policy_id IS NULL
      SQL
    end

    def insurables_with_active_policies
      Insurable.
        joins(:policies).
        send(@insurables_type).
        where(insurables: { account_id: @master_policy.account }).
        where(active_policies_condition).
        select('insurables.id').
        to_sql
    end

    def active_policies_condition
      <<-SQL
        policies.policy_type_id = #{@master_policy.policy_type_id}
        AND policies.status IN (#{active_statuses})
        AND policies.expiration_date > '#{Time.zone.now}'
      SQL
    end
    
    def active_statuses
      Policy.statuses.values_at('BOUND', 'BOUND_WITH_WARNING').join(', ')
    end
  end
end
