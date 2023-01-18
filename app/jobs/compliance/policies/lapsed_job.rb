# Todo: Fix this pile of awful... users getting upwards of 40 emails per day.
module Compliance
  module Policies
    class LapsedJob < ApplicationJob
      queue_as :default
      # before_perform :find_policies

      def perform(*)
        # unless @policies.blank?
        #   @policies.each do |policy|
        #     organization = policy.account.nil? ? policy.agency : policy.account
        #     organization = Agency.get_covered if organization.nil?
        #     Compliance::PolicyMailer.with(organization: organization)
        #                             .policy_lapsed(policy: policy, lease: policy.latest_lease).deliver_now
        #   end
        # end
      end

      private
      def find_policies
        # date = Date.current - 1.days
        # @policies = Policy.where(expiration_date: (date - 1.day)..date, status: ["EXPIRED", "CANCELLED"])
        #                   .or(Policy.where(cancellation_date: (date - 1.day)..date, status: ["EXPIRED", "CANCELLED"]))
      end

    end
  end
end