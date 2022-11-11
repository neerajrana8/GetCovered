module Compliance
  module Policies
    class LapsedJob < ApplicationJob
      queue_as :default
      before_perform :find_policies

      def perform(*args)
        @policies.each do |policy|
          Compliance::PolicyMailer.with(organization: policy.account).policy_expiring_soon(policy: policy).deliver_now
        end
      end

      private
      def find_policies
        date_one = DateTime.current.to_date + 7.days
        date_two = DateTime.current.to_date + 14.days
        date_three = DateTime.current.to_date + 21.days
        @policies = Policy.where(status: "BOUND", expiration_date: [date_one, date_two, date_three], policy_type_id: 1)
                          .or(Policy.where(status: "BOUND_WITH_WARNING", expiration_date: [date_one, date_two, date_three], policy_type_id: 1))
                          .or(Policy.where(status: "EXTERNAL_VERIFIED", expiration_date: [date_one, date_two, date_three], policy_type_id: 1))
      end
    end
  end
end
