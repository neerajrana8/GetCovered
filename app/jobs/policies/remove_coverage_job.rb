module Policies
  class RemoveCoverageJob < ApplicationJob
    before_perform :set_policies

    def perform()
      @policies.each do |policy|
        policy.update_coverage
      end
    end

    private
    def set_policies
      @policies = Policy.where(status: Policy.active_statuses,
                               policy_type_id: [1,3,4,5,6,8],
                               expiration_date: Time.current.to_date)
    end
  end
end