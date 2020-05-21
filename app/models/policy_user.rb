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
  
  validate :user_listed_once
  
  enum status: { invited: 0, accepted: 1, disputed: 2, removed: 3 }
  enum dispute_status: { undisputed: 0, in_process: 1, resolved: 2 }
  
  def dispute
    return update(status: "disputed", disputed_at: Time.now, dispute_status: "in_process") ? true : false
  end
  
  def resolve_dispute(remove = nil)
    raise ArgumentError, 'Must indicate if removal is necessary' if remove.nil?
    update_status = remove ? "removed" : "accepted"
    return update(status: update_status, dispute_status: "resolved") ? true : false
  end
  
  def invite
    
    invite_sent = false
    
    unless disputed? || 
           accepted? ||
           primary? ||
           policy.nil? ||
           user.nil?
      
      links = {
        :accept => "#{ Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client] }/confirm-policy",
        :dispute => "#{ Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client] }/dispute-policy" 
      }
      
      UserCoverageMailer.with(policy: policy, user: user, links: links).added_to_policy().deliver
      invite_sent = true
    end
    
    return invite_sent
  end
  
  def accept(email = nil)
    raise ArgumentError, 'Email must be present to verify acceptance' if email.nil?
    
    acceptance_status = false
    
    if user.email == email
      if update(status: "accepted")
        UserCoverageMailer.with(policy: policy, user: user).proof_of_coverage().deliver_later
        acceptance_status = true 
      end
    end
    
    return acceptance_status
  end
  
  private
    
    def set_first_as_primary
      ref_model = policy.nil? ? policy_application : policy
      if ref_model.policy_users.count == 0
        self.primary = true  
        self.status = "accepted"
      end  
    end
     
    def set_account_user
      ref_model = policy.nil? ? policy_application : policy
			policy_type_check = ref_model.policy_type == PolicyType.find(4) || 
													ref_model.policy_type == PolicyType.find(5)
      unless policy_type_check && ref_model.account.nil?
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
    
    def user_listed_once
      if policy_application
        user_ids = policy_application.users.map(&:id)
        errors.add(:user, "Already included on policy or policy application") if user_ids.count(user.id) > 1  
      end
    end
end
