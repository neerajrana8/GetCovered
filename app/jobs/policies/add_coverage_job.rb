module Policies
  class AddCoverageJob < ApplicationJob
    before_perform :set_policies

    def perform()
      @policies.each do |policy|
        policy.update_coverage
      end
    end

    private
    def set_policies
      @policies = Policy.where(status: Policy.active_statuses, effective_date: Time.current.to_date)
    end
  end
end