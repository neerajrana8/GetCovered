module CarrierQBE
  class MarkRenewalUpcomingJob < ApplicationJob
    queue_as :default
    before_perform :find_policies

    def perform(*)
      @policies.each do |policy|
        policy.update renewal_status: "UPCOMING"
      end
    end

    private

    def find_policies
      @policies = Policy.where(expiration_date: Time.current.to_date..(Time.current.to_date + 60.days),
                               status: ["BOUND", "BOUND_WITH_WARNING"],
                               renewal_status: ["NONE", "RENEWED"],
                               policy_type_id: ::PolicyType::RESIDENTIAL_ID,
                               carrier_id: 1,
                               policy_in_system: true,
                               billing_status: [Policy.billing_statuses["CURRENT"],
                                                Policy.billing_statuses["BEHIND"],
                                                Policy.billing_statuses["RESCINDED"]])
    end
  end
end