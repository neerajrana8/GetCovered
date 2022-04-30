module Compliance
  module Policies
    class LapsedJob < ApplicationJob
      queue_as :default
      before_perform :find_policies

      def perform(*)
        unless @policies.blank?
          @policies.each do |policy|
            # Disabled for now!
            # needs a fix for policy.cancellation_date and a mechanism to identify related lease.
            #
            # Compliance::PolicyMailer.with(organization: policy.account.nil? ? policy.agency : policy.account)
            #                         .policy_lapsed(policy: policy, lease: nil)
          end
        end
      end

      private
      def find_policies
        @policy_ids = []
        date = Date.current - 1.days
        master_policies = Policy.where(policy_type_id: 2, carrier_id: 2)
        master_policies.each do |master|
          master.insurables.communities.each do |community|
            # Get Policy IDs for Policies that expired in the last 24 hours
            expired_policies = PolicyInsurable.joins(:policy)
                                              .where(policy: {
                                                       expiration_date: (date - 1.day)..date,
                                                       status: "EXPIRED"
                                                     },
                                                     insurable_id: community.units.pluck(:id),
                                                     primary: true).pluck(:policy_id)
            # Get Policy IDs for Policies that cancelled in the last 24 hours
            cancelled_policies = PolicyInsurable.joins(:policy)
                                                .where(policy: {
                                                         expiration_date: (date - 1.day)..date,
                                                         status: "CANCELLED"
                                                       },
                                                       insurable_id: community.units.pluck(:id),
                                                       primary: true).pluck(:policy_id)

            @policy_ids = @policy_ids + expired_policies
            @policy_ids = @policy_ids + cancelled_policies

          end
        end
        @policies = @policy_ids.blank? ? nil : Policy.find(@policy_ids)
      end
    end
  end
end