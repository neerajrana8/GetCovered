module LeadEvents
  class LinkPolicyApplicationUsers < ActiveInteraction::Base
    object :policy_application

    delegate :users, :primary_user, to: :policy_application

    def execute
      users.pluck(:id, :email).each do |id, email|
        Lead.find_by_email(email)&.update(user_id: id)
      end
      Lead.find_by_email(primary_user&.email)&.update(user_id: primary_user.id) if primary_user.present?
    end
  end
end
