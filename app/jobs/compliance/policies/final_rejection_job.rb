module Compliance
  module Policies
    class FinalRejectionJob < ApplicationJob
      queue_as :default
      before_perform :find_policies

      def perform(*args)
        @policies.each do |policy|
          Compliance::PolicyMailer.with(organization: policy.account.nil? ? policy.agency : policy.account)
                                  .external_policy_status_changed(policy: policy)
                                  .deliver_now()
        end
      end

      private
      def find_policies
        base_date = DateTime.current = 192.hours
        @policies = Policy.where(status: "EXTERNAL_REJECTED", status_changed_on: base_date.at_beginning_of_day..base_date.at_end_of_day)
      end

    end
  end
end
