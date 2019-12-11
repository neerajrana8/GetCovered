# Policy User model
# file: app/models/policy_user.rb

class PolicyUser < ApplicationRecord
  
  # Callbacks
  before_create :set_first_as_primary
  after_create :set_account_user, 
    if: Proc.new { |pol_usr| !pol_usr.user.nil? }
  
  belongs_to :policy_application, optional: true
  belongs_to :policy, optional: true
  belongs_to :user, optional: true
  
  accepts_nested_attributes_for :user
  
  private
    
    def set_first_as_primary
      ref_model = policy.nil? ? policy_application : policy
      if ref_model.policy_users.count == 0
        self.primary = true  
      end  
    end
     
    def set_account_user
      ref_model = policy.nil? ? policy_application : policy
      unless ref_model.policy_type == PolicyType.find(4) && 
             ref_model.account.nil?
        acct = AccountUser.where(user_id: user.id, account_id: ref_model.account_id).take
        if acct.nil?
          AccountUser.create!(user: user, account: ref_model.account)
        elsif acct.status != 'enabled'
          acct.update(status: 'enabled')
        else
          # do nothing
        end
      end
    end

end
