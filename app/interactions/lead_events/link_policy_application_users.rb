module LeadEvents
  class LinkPolicyApplicationUsers < ActiveInteraction::Base
    object :policy_application

    delegate :users, to: :policy_application

    def execute
      users.pluck(:id, :email).each do |id, email|
        Lead.find_by_email(email)&.update(user_id: id)
      end
    end
  end
end
