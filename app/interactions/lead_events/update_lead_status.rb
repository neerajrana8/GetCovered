module LeadEvents
  class UpdateLeadStatus < ActiveInteraction::Base
    object :policy_application

    delegate :users, to: :policy_application

    def execute
      users.pluck(:email).each do |email|
        Lead.find_by_email(email)&.update(status: Lead.statuses[:converted])
      end
    end
  end
end
