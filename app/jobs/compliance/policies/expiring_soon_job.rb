module Compliance
  module Policies
    class ExpiringSoonJob < ApplicationJob
      queue_as :default
      before_perform :find_policies

      def perform(*args)
        @policies.each do |policy|
          Compliance::PolicyMailer.with(organization: policy.account).policy_expiring_soon(policy: policy).deliver_now
        end
      end

      private

      def find_policies
        @policies = Policy.where(status: ["BOUND", "BOUND_WITH_WARNING", "EXTERNAL_VERIFIED"],
                                 expiration_date: DateTime.current.to_date + 7.days,
                                 policy_type_id: 1).distinct
      end
    end
  end
end
