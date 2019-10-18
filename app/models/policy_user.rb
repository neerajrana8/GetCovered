# Policy User model
# file: app/models/policy_user.rb

class PolicyUser < ApplicationRecord
  
  # Callbacks
  after_create :set_account_user, 
    if: Proc.new { |pol_usr| !pol_usr.user.nil? }
  
  belongs_to :policy_application, optional: true
  belongs_to :policy, optional: true
  belongs_to :user, optional: true
  
  private
   
    def set_account_user
      ref_model = policy.nil? ? policy_application : policy
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
