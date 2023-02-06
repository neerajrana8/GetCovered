module Policies
  class ExpireJob < ApplicationJob
    queue_as :default
    before_perform :find_policies

    def perform(*args)
      @policies.each do |policy|
        policy.update status: "EXPIRED"
      end
    end

    private
    def find_policies
      @policies = Policy.where(expiration_date: DateTime.current.to_date,
                               status: ["BOUND", "BOUND_WITH_WARNING", "EXTERNAL_UNVERIFIED", "EXTERNAL_VERIFIED"],
                               policy_type_id: 1).distinct
    end
  end
end
