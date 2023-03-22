module Compliance
  module Policies
    class ExpiringSoonJob < ApplicationJob
      queue_as :default
      before_perform :find_policies

      def perform(*args)
        @policies.each do |policy|
          Compliance::PolicyMailer.with(organization: policy.account).policy_expiring_soon(policy: policy).deliver_now unless was_already_sent?(policy)
        end
      end

      private

      def find_policies
        @policies = Policy.where(status: ["BOUND", "BOUND_WITH_WARNING", "EXTERNAL_VERIFIED"],
                                 expiration_date: Date.today + 7.days,
                                 policy_type_id: 1).distinct
      end

      #TODO: need to move to service object
      def was_already_sent?(policy)
        ContactRecord.where(subject: I18n.t('policy_mailer.policy_expiring_soon.subject'), contactable_type: "User", contactable_id: policy&.primary_user.id).count > 0
      end
    end
  end
end
