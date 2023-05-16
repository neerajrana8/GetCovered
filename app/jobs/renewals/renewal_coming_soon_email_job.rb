module Renewals
  class RenewalComingSoonEmailJob < ApplicationJob
    queue_as :default
    before_perform :find_policies

    def perform(*args)
      @policies.each do |policy|
        RenewalMailer.with(policy: policy).policy_renewing_soon.deliver_later
      end
    end

    private

    def find_policies
      @policies = Policy.where(expiration_date: DateTime.current.to_date + 29.days,
                               status: ["BOUND", "BOUND_WITH_WARNING"],
                               policy_type_id: ::PolicyType::RESIDENTIAL_ID,
                               carrier_id: 1,
                               policy_in_system: true,
                               billing_status: [Policy.billing_statuses["CURRENT"], Policy.billing_statuses["RESCINDED"]]
                               ).distinct
    end
  end
end
