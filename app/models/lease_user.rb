# Lease User model
# file: app/models/lease_user.rb

class LeaseUser < ApplicationRecord
  
  # Callbacks
  after_create :set_account_user
  
  # Relationships
  belongs_to :lease
  belongs_to :user
    
  def related_records_list
    return ['lease', 'user']  
  end
  
  private
   
    def set_account_user
      acct = AccountUser.where(user_id: user.id, account_id: lease.account_id).take
      if acct.nil?
        AccountUser.create!(user: user, account: lease.account)
      elsif acct.status != 'enabled'
        acct.update(status: 'enabled')
      else
        # do nothing
      end
    end

end
