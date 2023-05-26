module CarrierQBE
  class PrepareForRenewalJob < ApplicationJob
    queue_as :default
    before_perform :find_policies

    def perform(*args)
      @policies.each do |policy|
        begin
          Qbe::Renewal::Prepare.call(policy)
        rescue Exception => e
          # Todo: there should be some kind of notification here
          Rails.logger.debug e
        end
      end
    end

    private

    def find_policies
      @policies = Policy.where(expiration_date: (Time.current.to_date)..(Time.current.to_date + 29.days),
                               status: ["BOUND", "BOUND_WITH_WARNING"],
                               renewal_status: ["NONE", "UPCOMING", "PREPARATION_FAILED"],
                               policy_type_id: ::PolicyType::RESIDENTIAL_ID,
                               carrier_id: 1,
                               policy_in_system: true,
                               billing_status: [Policy.billing_statuses["CURRENT"],
                                                Policy.billing_statuses["BEHIND"],
                                                Policy.billing_statuses["RESCINDED"]]
      )
    end

  end
end